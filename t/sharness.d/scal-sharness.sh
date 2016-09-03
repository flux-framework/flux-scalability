#
# This test must be run with an installed flux-core and flux-sched
#

#
# Internal file update routines
#
cp_results_file() {
    local o=${1}
    local dir=${2}
    local caller=${3}
    if test $# -ne 3; then
        echo <&2 "${caller}: bad input"
        return 1
    elif ! test -f "$o"; then
        echo <&2 "${caller}: nonexistent file : ${o}"
        return 1
    elif ! test -d "$dir"; then
        echo <&2 "${caller}: nonexistent dir: ${dir}"
        return 1
    fi 
    cp -f "${o}" "${dir}"
}

update_rawdata_header() {
    local o="${1}.csv"
    if test $# -ne 1; then
        echo <&2 "update_rawdata_header: bad input"
        return 1
    fi
    echo "jobid,s-time,r-time,c-time,nnodes,ntasks" > ${o}
    return 0
}

update_rawdata() {
    local o="${1}.csv"
    if test $# -ne 7; then
        echo <&2 "update_rawdata: bad input"
        return 1
    fi
    csv_fm="%s,%s,%s,%s,%s,%s"
    printf "${csv_fm}\n" "$2" "$3" "$4" "$5" "$6" "$7" >> ${o}
    return 0
}

cp_rawdata_file() {
    local o="${1}.csv"
    local dir=${2}
    cp_results_file "${o}" "${dir}" "cp_rawdata_file"
}

update_ival_header() {
    local o1="${1}.in.stats"
    if test $# -ne 1; then
        echo <&2 "update_ival_header: bad input"
        return 1
    fi
    echo "job-group-id,used-nodes,job-count,JEPS" > $o1
}

update_ival_metrics() {
    local o1="${1}.in.stats"
    local gid=${2}
    local njobs=${3}
    local rout=${4}
    local elapse=$(echo "${6}-${5}" | bc -l)
    if test $# -ne 6; then
        echo <&2 "update_ival_metrics: bad input"
    fi

    local usedcount=$(cat $rout | cut -d'.' -f4 | sort | uniq | wc -l)
    local JEPS=$(echo "${njobs}.0/$elapse" | bc -l)
    local fm="%s,%s,%s,%s"
    printf "${fm}\n" "$gid" "$usedcount" "$njobs" "$JEPS" >> $o1
}

cp_ival_metrics_file() {
    local o="${1}.in.stats"
    local dir=${2}
    cp_results_file "${o}" "${dir}" "cp_ival_metrics_file"
}

update_ov_header() {
    local o2="${1}.ov.stats"
    if test $# -ne 1; then
        echo <&2 "update_overall_header: bad input"
        return 1
    fi
    echo "base-time,used-nodes,job-count,task-count,time-elapsed,JEPS,TEPS" > $o2
}

update_ov_metrics() {
    local o2="${1}.ov.stats"
    local njobs=${2}
    local rout=${3}
    local taskcnt=${4}
    local e2e_elapse=$(echo "${6}-${5}" | bc -l)
    local job_elapse=$(echo "${8}-${7}" | bc -l)
    if test $# -ne 8; then
        echo <&2 "update_overall_metrics: bad input"
        return 1
    fi

    local fm="%s,%s,%s,%s,%s,%s,%s"
    local uc=$(cat $rout | cut -d'.' -f4 | sort | uniq | wc -l)
    local JEPS=$(echo "${njobs}.0/$job_elapse" | bc -l)
    local TEPS=$(echo "${taskcnt}.0/$job_elapse" | bc -l)
    printf "${fm}\n" "elapse-time" "$uc" "$njobs" "$taskcnt" "$job_elapse" "$JEPS" "$TEPS" >> $o2
    JEPS=$(echo "${njobs}.0/$e2e_elapse" | bc -l)
    TEPS=$(echo "${taskcnt}.0/$e2e_elapse" | bc -l)
    printf "${fm}\n" "e2e-time" "$uc" "$njobs" "$taskcnt" "$e2e_elapse" "$JEPS" "$TEPS" >> $o2
    return 0
}

cp_ov_metrics_file() {
    local o="${1}.ov.stats"
    local dir=${2}
    cp_results_file "${o}" "${dir}" "cp_ov_metrics_file"
}

#
# Internal variables for test session management 
#
sched_instance_size=0
sched_test_session=0
sched_start_jobid=0
sched_end_jobid=0

# PUBLIC:
#   Accessors 
#
get_instance_size() {
    if test "$sched_instance_size" -eq 0; then
        sched_instance_size=$(flux getattr size)
    fi
    echo "$sched_instance_size"
}

get_session() {
    echo "$sched_test_session"
}

get_start_jobid() {
    echo "$sched_start_jobid"
}

get_end_jobid() {
    echo "$sched_end_jobid"
}

set_session() {
    sched_test_session=$1
}

set_start_jobid() {
    sched_start_jobid=$1
}

set_end_jobid() {
    sched_end_jobid=$1
}

adjust_session_info () {
    local njobs=$1
    set_session $(($(get_session) + 1))
    set_start_jobid $(($(get_end_jobid) + 1))
    set_end_jobid $(($(get_start_jobid) + $njobs - 1))
    return 0
}

# PUBLIC:
#   Run flux-jstat in background. Wait up to 2 seconds 
#   until flux-jstat gets ready to receive JSC events. 
#   jstat's output will be printed to $1.<session id>
#
timed_run_flux_jstat() {
    local fn=$1
    ofile=${fn}.$sched_test_session
    rm -f ${ofile}
    flux jstat -o ${ofile} notify >/dev/null &
    echo $! &&
    $SHARNESS_TEST_SRCDIR/scripts/waitfile.lua --timeout 2 ${ofile} >&2
}

# PUBLIC:
#   Run flux-waitjob in background. Wait up to $1 seconds
#   until flux-waitjob gets ready to receive JSC events. 
#   waitjob creates wo.st.<session id> to signal its readiness
#   and wo.end.<session id> to indicate the specified job
#   has completed.
#
timed_wait_job() {
    local tout=$1
    flux waitjob -s wo.st.$sched_test_session \
         -c wo.end.$sched_test_session $sched_end_jobid &
    $SHARNESS_TEST_SRCDIR/scripts/waitfile.lua --timeout ${tout} \
        wo.st.$sched_test_session >&2
    return $?
}

# PUBLIC:
#   Wait up to $1 seconds until the previously invoked flux-waitjob
#   detects the final job has completed.
#
timed_sync_wait_job() {
    local tout=$1
    $SHARNESS_TEST_SRCDIR/scripts/waitfile.lua --timeout ${tout} \
        wo.end.$sched_test_session >&2
    return $?
}

next_power_2_cores() {
    local cores=$1
    cores=$((cores*2))
    if test "$cores" -gt "$2"; then
        cores=1 
    fi
    echo "$cores" 
} 

# PUBLIC:
#   Submit unit jobs.
#     $1: sleep or mpisleep 
#     $2: unit, half, power_2
#     $3: nnodes 
#
submit_sleep_jobs() {
    local ex=${1:-usleep}
    local s=${2:-unit}
    local nnodes=${3:-1}
    local cores=1
    local taskcount=0
    
    if test "$nnodes" -lt 1; then
        echo <&2 "submit_sleep_jobs: bad input"
        return 1
    elif test "$ex" != "usleep" -a $ex != "mpiusleep"; then
        echo <&2 "submit_sleep_jobs: unknown sleep command"
        return 1
    elif test "$s" != "unit" -a "$s" != "half" -a "$s" != "power_2"; then
        echo <&2 "submit_sleep_jobs: unknown sizing policy"
        return 1
    fi

    if test "$s" = "half"; then
        if test "$nnodes" -gt 1; then
            cores=$((nnodes/2)) 
        else
            echo <&2 "submit_sleep_jobs: nnodes must be greater than 1"
            return 1 
        fi
    fi
    for i in `seq $sched_start_jobid $sched_end_jobid`
    do
        taskcount=$((taskcount+cores))
        flux submit -n "$cores" "$ex" 0
        if test $? -ne 0; then
            echo <&2 "flux submit failed"
            return 1
        fi
        if test "$s" = "power_2"; then
            cores=$(next_power_2_cores $cores $nnodes)
        fi
    done
    rc=$?
    echo ${taskcount}
    return ${rc}
} 

# PUBLIC:
#   Run unit jobs.
#     $1: sleep or mpisleep 
#     $2: unit, half, power_2
#     $3: nnodes 
#
wreckrun_sleep_jobs() {
    local ex=${1:-usleep}
    local s=${2:-unit}
    local nnodes=${3:-1}
    local cores=1
    local taskcount=0
    
    if test "$nnodes" -lt 1; then
        echo <&2 "wreckrun_sleep_jobs: bad input"
        return 1
    elif test "$ex" != "usleep" -a $ex != "mpiusleep"; then
        echo <&2 "wreckrun_sleep_jobs: unknown sleep command"
        return 1
    elif test "$s" != "unit" -a "$s" != "half" -a "$s" != "power_2"; then
        echo <&2 "wreckrun_sleep_jobs: unknown sizing policy"
        return 1
    fi

    if test "$s" = "half"; then
        if test "$nnodes" -gt 1; then
            cores=$((nnodes/2)) 
        else
            echo <&2 "wreckrun_sleep_jobs: nnodes must be greater than 1"
            return 1 
        fi
    fi
    for i in `seq $sched_start_jobid $sched_end_jobid`
    do
        taskcount=$((taskcount+cores))
        flux wreckrun --detach -n "$cores" "$ex" 0
        if test $? -ne 0; then
            echo <&2 "flux wreckrun --detach failed"
            return 1
        fi
        if test "$s" = "power_2"; then
            cores=$(next_power_2_cores $cores $nnodes)
        fi
    done
    rc=$?
    echo ${taskcount}
    return ${rc}
} 

# PUBLIC:
#   Fetch, compute and store timing information 
#     $1: base output file name 
#     $2: begin time to compute end-to-end timing
#     $3: end time to compute end-to-end timiming
#     $4: granularity to compute possible peformnace degradation overtime
#         (e.g., passing 1000 asks this function to compute 
#          performnace metrics for every seperate 1000 jobs
#          in addition to overall performance metrics)
#     $5: total number of tasks scheduled
dump_timing_info() {
    local o=${1}
    local -a e2e_elapse=(${2} ${3})
    local gran=${4}
    local tasks=${5}

    if test $# -ne 5; then
        echo >&2 "dump_timing_info: incorrect arg count"
        return 1
    elif test $gran -gt $((sched_end_jobid - sched_start_jobid + 1)); then
        echo >&2 "dump_timing_info: bad input" 
        return 1
    elif test $((e2e_elapse[1] - e2e_elapse[0])) -lt 0; then 
        echo >&2 "dump_timing_info: end time is greter then begin time" 
        return 1
    elif test $((tasks)) -lt 1; then
        echo >&2 "dump_timing_info: invalid total number of tasks"
        return 1
    fi

    #update_rawdata_header ${o} &&
    update_ival_header ${o} && update_ov_header ${o} || return 1

    local rout="ranks.$(get_session)"
    local ni=0 # normalized jobid 
    local gid=0 # group id incremented at every $gran jobs
    local njobs=0
    local -a fx
    local -a task_stat
    # st[0] is the beginning time stamp 
    # its granularity is interval. st[1]'s granularity is 
    # the whole operation
    local -a st
    st[0]=$(flux kvs get "lwj.${sched_start_jobid}.starting-time")
    st[1]=${st[0]}

    for i in `seq $((sched_start_jobid-1)) ${gran} ${sched_end_jobid}`
    do
        ni=$((i-sched_start_jobid))
        if test $((ni%gran)) -eq $((gran-1)); then
            fx[0]=$(flux kvs get "lwj.${i}.starting-time")
            fx[1]=$(flux kvs get "lwj.${i}.running-time")
            fx[2]=$(flux kvs get "lwj.${i}.complete-time")
            fx[3]=$(flux kvs get "lwj.${i}.nnodes")
            fx[4]=$(flux kvs get "lwj.${i}.ntasks")
            flux kvs dir "lwj.${i}.rank" >> "${rout}.ts"

            #update_rawdata "$o" ${i} \
            #${fx[0]} ${fx[1]} ${fx[2]} ${fx[3]} ${fx[4]}

            update_ival_metrics "$o" $((ni/gran)) ${gran} "${rout}.ts" \
                ${st[0]} ${fx[2]}
            cat "${rout}.ts" >> "${rout}"
            rm -f "${rout}.ts"
            st[0]=${fx[2]}
        fi
    done

    if test -f ${rout}.ts; then
        njobs=$((ni%gran+1))
        update_ival_metrics "$o" $((ni/gran)) ${njobs} "$rout.ts" \
            ${st[0]} ${fx[2]}
        cat $rout.ts >> $rout
        rm -f $rout.ts
    fi  
    
    njobs=$((sched_end_jobid-sched_start_jobid+1))
    update_ov_metrics "$o" ${njobs} "$rout" ${tasks} \
        ${e2e_elapse[0]} ${e2e_elapse[1]} ${st[1]} ${fx[2]} || return 1

    #cp_rawdata_file ${o} ${SCAL_TST_RESULTS_DIR} && \
    cp_ival_metrics_file ${o} ${SCAL_TST_RESULTS_DIR} && \
    cp_ov_metrics_file ${o} ${SCAL_TST_RESULTS_DIR} || return 1
}

#  PUBLIC:
#  Reinvoke a test file under a flux comms instance
#  using the rexec command string passed in (e.g., "srun -N4 -n4").
#
#  Usage: test_under_flux_w_rexec <rexec string> 
#
test_under_flux_w_rexec() {
    runcmd=${1:-1}
    test_inst_name=${2:-""}
    persist_fs=${3:-""}
    log_file="$TEST_NAME.$test_inst_name.broker.log"

    if test -n "$TEST_UNDER_FLUX_ACTIVE" ; then
        cleanup rm "${SHARNESS_TEST_DIRECTORY:-..}/$log_file"
        return
    fi
    quiet="-o -q,-Slog-filename=${log_file},-Slog-forward-level=7"
    if test "$verbose" = "t" -o -n "$FLUX_TESTS_DEBUG" ; then
        flags="${flags} --verbose"
        quiet=""
    fi
    if test "$debug" = "t" -o -n "$FLUX_TESTS_DEBUG" ; then
        flags="${flags} --debug"
    fi
    if test -n "$logfile" -o -n "$FLUX_TESTS_LOGFILE" ; then
        flags="${flags} --logfile"
    fi
    if test -n "$SHARNESS_TEST_DIRECTORY"; then
        cd $SHARNESS_TEST_DIRECTORY
    fi
    persist=""
    if test "x$persist_fs" != "x"; then
        persist="-o -Spersist-filesystem=$persist_fs"
    fi

    TEST_UNDER_FLUX_ACTIVE=t \
    TERM=${ORIGINAL_TERM} \
      exec $runcmd flux start ${quiet} ${persist} "sh $0 ${flags}"
}

# vi: ts=4 sw=4 expandtab
