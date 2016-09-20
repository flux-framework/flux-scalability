#!/bin/sh
#set -x

error_exit() {
    msg=${1:-Error}
    echo >&2 $msg
    exit 1
} 

#
# print_w_leading_zeroes num [digits] 
#     num: a positive integer, whose digit count must be less than or equal to max
#     digits: the num of digits to print (e.g., digits=2, num=3 will print 03). 
#             default is 8 and must not be greater than 8
#
print_w_leading_zeroes() {
    n=${1:-1}
    m=${2:-8}
    if test $n -lt 0 -o ${#n} -gt $m -o $m -gt 8; then
        error_exit "print_w_leading_zeroes: bad input"
    fi
    while test ${#n} -ne $m;
    do
        n="0"$n
    done
    echo "$n"
}

flux --help >/dev/null 2>&1 || error_exit "Failed to find flux in PATH"

#
# A bunch of environment variables should be set by the upper level script. 
# However, for a case where some variables are missing, 
# this script tries to pick default values to these variables. 
#
SCAL_TST_WLM=${SCAL_TST_WLM:-MOAB}
SCAL_TST_RM=${SCAL_TST_RM:-SLURM}
SCAL_TST_NODES=${SCAL_TST_NODES:-1}
SCAL_TST_BROKERS_PER_NODE=${SCAL_TST_BROKERS_PER_NODE:-$SCAL_TST_NODES}
SCAL_TST_SLEEP_CMD=${SCAL_TST_SLEEP_CMD:-usleep}
SCAL_TST_SIZING_POLICY=${SCAL_TST_SIZING_POLICY:-unit}
SCAL_TST_PERSIST_FS=${SCAL_TST_PERSIST_FS:-/nfs/tmp2/$USER}
SCAL_TST_RESULTS_DIR=$SHARNESS_TEST_SRCDIR/$OUTPUT_DIR
mkdir -p ${SCAL_TST_RESULTS_DIR}
SCAL_TST_NUM_JOBS=${SCAL_TST_NUM_JOBS:-10000}
SCAL_TST_TARGET=${SCAL_TST_TARGET:-3600}

case $SCAL_TST_RM  in
    SLURM|slurm)
    DFLT_REXEC_STR="srun -N${SCAL_TST_NODES} \
--ntasks-per-node=${SCAL_TST_BROKERS_PER_NODE}"
    ;;
    *)
    echo >&2 "Unsupported resource manager."
    exit 1
    ;;
esac

SCAL_TST_REXEC_STR=${SCAL_TST_REXEC_STR:-$DFLT_REXEC_STR}

SCAL_TST_SCHED_POLICY=${SCAL_TST_SCHED_POLICY:-fcfs}
SCAL_TST_QUEUE_DEPTH=${SCAL_TST_QUEUE_DEPTH:-16}
SCAL_TST_DELAY=${SCAL_TST_DELAY:-false}
QD="sched-params=queue-depth=${SCAL_TST_QUEUE_DEPTH}"
DL="delay-sched=${SCAL_TST_DELAY}"
SCHED_PARAMS="${QD},${DL}"

case $SCAL_TST_SCHED_POLICY in
    fcfs|FCFS)
    FLUX_SCHED_OPTIONS="${SCHED_PARAMS} plugin=sched.fcfs"
    ;;
    easy|EASY)
    BACKFILL="plugin=sched.backfill plugin-opts=reserve-depth=1"
    FLUX_SCHED_OPTIONS="${SCHED_PARAMS} ${BACKFILL}"
    ;;
    conservative|CONSERVATIVE)
    BACKFILL="plugin=sched.backfill plugin-opts=reserve-depth=-1"
    FLUX_SCHED_OPTIONS="${SCHED_PARAMS} ${BACKFILL}"
    ;;
    hybrid100|HYBRID100)
    BACKFILL="plugin=sched.backfill plugin-opts=reserve-depth=100"
    FLUX_SCHED_OPTIONS="${SCHED_PARAMS} ${BACKFILL}"
    ;;
    wreckrun|WRECKRUN)
    FLUX_SCHED_RC_NOOP="yes"
    ;;
    *)
    echo >&2 "Unknown scheduling policy: ${SCAL_TST_SCHED_POLICY}"
    exit 1
    ;;
esac

ENV_PAIR=${SCAL_TST_WLM}.${SCAL_TST_RM}
WL_PAIR=${SCAL_TST_SIZING_POLICY}.${SCAL_TST_SLEEP_CMD}.${SCAL_TST_SCHED_POLICY}
WL_PAIR=${WL_PAIR}.QD${SCAL_TST_QUEUE_DEPTH}.DELAY${SCAL_TST_DELAY}
PAD_NODES=$(print_w_leading_zeroes $SCAL_TST_NODES 5)
PAD_BPN=$(print_w_leading_zeroes $SCAL_TST_BROKERS_PER_NODE 2)
BCOUNT=$((SCAL_TST_NODES*SCAL_TST_BROKERS_PER_NODE))
PAD_BCOUNT=$(print_w_leading_zeroes $BCOUNT)
PTP=$(print_w_leading_zeroes $SCAL_TST_NUM_JOBS 8).${SCAL_TST_TARGET}
TST_CONFIG=${ENV_PAIR}.${PAD_BCOUNT}.${PAD_NODES}Nx${PAD_BPN}B.${WL_PAIR}.${PTP}
SCAL_TST_CONFIG=${SCAL_TST_CONFIG:-$TST_CONFIG}

export SCAL_TST_WLM
export SCAL_TST_RM
export SCAL_TST_NODES
export SCAL_TST_BROKERS_PER_NODE
export SCAL_TST_REXEC_STR
export SCAL_TST_SLEEP_CMD
export SCAL_TST_SIZING_POLICY
export SCAL_TST_CONFIG
export SCAL_TST_SCHED_POLICY
export SCAL_TST_NUM_JOBS
export SCAL_TST_TARGET
export SCAL_TST_RESULTS_DIR
export SCAL_TST_PERSIST_FS
if ! test -z ${FLUX_SCHED_RC_NOOP}; then
    export FLUX_SCHED_RC_NOOP
    unset FLUX_SCHED_OPTIONS
else
    export FLUX_SCHED_OPTIONS
fi

# vi: ts=4 sw=4 expandtab
