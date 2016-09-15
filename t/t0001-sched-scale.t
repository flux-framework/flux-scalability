#!/bin/sh

test_description='Run the basic scheduler scalability tests at: 
    - System Workload Manager: ${SCAL_TST_WLM}
    - System Resource Manager (REXEC): ${SCAL_TST_RM}
    - Number of Compute Nodes: ${SCAL_TST_NODES} 
    - Number of Brokers Per Node: ${SCAL_TST_BROKERS_PER_NODE}
    - MPI vs Non-MPI: ${SCAL_TST_SLEEP_CMD}
    - Job Sizing Policy: ${SCAL_TST_SIZING_POLICY}
    - flux-sched Scheduling Policy: ${SCAL_TST_SCHED_POLICY}
    - Queue depth: ${SCAL_TST_QUEUE_DEPTH}
    - Delay: ${SCAL_TST_DELAY}

Produce performance profiles; ensure that the basics
of scalability tests work at this configuration.
'

#
# source sharness from the directory where this test
# file resides
#
. $(dirname $0)/sharness.sh

#
# test_under_flux_w_rexec is under sharness.d/
#
test_under_flux_w_rexec "${SCAL_TST_REXEC_STR}" "${SCAL_TST_CONFIG}" \
    "${SCAL_TST_PERSIST_FS}"

test_expect_success "sched at ${SCAL_TST_CONFIG}: size matches config" '
    flux getattr size > size.out &&
    sz=$(($SCAL_TST_NODES*$SCAL_TST_BROKERS_PER_NODE)) &&
    test $(cat size.out) = $sz 
'

test_expect_success "sched at ${SCAL_TST_CONFIG}: sched module loaded" '
    flux module list | egrep "hwloc|job|sched" > modules.out &&
    test $(cat modules.out | wc -l) -eq 3 
'

test_expect_success "sched at ${SCAL_TST_CONFIG}: persist fs attr matches" '
    echo "${SCAL_TST_PERSIST_FS}" &&
    test -d "${SCAL_TST_PERSIST_FS}" &&
    fs=$(flux getattr persist-filesystem)  &&
    test "$fs" = "${SCAL_TST_PERSIST_FS}" 
'

test_expect_success "sched at ${SCAL_TST_CONFIG}: BPN matches config" '
    adjust_session_info 1 &&
    timed_wait_job 5 &&
    flux submit -N ${SCAL_TST_NODES} --tasks-per-node=1 --output=h.out hostname &&
    timed_sync_wait_job 2 &&
    res=$(cat h.out | uniq -c | gawk '\''{print $1}'\'' | uniq | wc -l) &&
    test $res -eq 1
'

MAIN_TST_MSG="run ${SCAL_TST_NUM_JOBS} jobs in ${SCAL_TST_TARGET} secs"
test_expect_success "sched at ${SCAL_TST_CONFIG}: ${MAIN_TST_MSG}" '
    adjust_session_info ${SCAL_TST_NUM_JOBS} &&
    st_jobid=$(get_start_jobid)
    gran=1000 &&
    flux cron event -n ${gran} wreck.state.complete flux wreck purge -v -Rt 256 -k \'\''id-${st_jobid} == 0 or \(id-${st_jobid}+1\)%${gran} == 0\'\'' &&
    timed_wait_job 5 &&
    n=${SCAL_TST_NODES} &&
    ts_begin=$(date +%s) && 
    t=$(submit_sleep_jobs ${SCAL_TST_SLEEP_CMD} ${SCAL_TST_SIZING_POLICY} ${n}) &&
    timed_sync_wait_job ${SCAL_TST_TARGET} &&
    ts_end=$(date +%s) &&
    dump_timing_info ${SCAL_TST_CONFIG} ${ts_begin} ${ts_end} ${gran} ${t} 
'

test_done
