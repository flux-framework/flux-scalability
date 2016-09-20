#!/bin/sh

SCRIPT_NM="perfexplore.sh"
SHORT_OPTSTR="p:q:d:j:s:c:N:B:m:R:W:P:l:o:Thy"
SCHED_OPTS="sched-policies:,queue-depths:,delay:,njobs:,job-sizing:,codes:"
SCAL_OPTS="nnodes:,nbrokers:,makespan:"
CONF_OPTS="resource-mgr:,workload-mgr:,precedence:,limit:,output-dir:"
QUERY_OPTS="tap-results"
LONG_OPTSTR="${SCHED_OPTS},${SCAL_OPTS},${CONF_OPTS},${QUERY_OPTS},help,dry-run"

# SCHED parameter space
sched_policy_params="FCFS EASY CONSERVATIVE HYBRID100"
sched_queue_depths="16"
sched_delay="true"
num_jobs_params="2000 10000"
sizing_policy_params="unit half power_2"
codes_params="usleep mpiusleep"

# Scalability parameter space
nnodes_params="2 4 8 16 32"
bpn_params="1"
duration=10800

# Config
RM="SLURM"
WL="MOAB"
PRECEDENCE="N B c s p q d j"
REF_PRECEDENCE=${PRECEDENCE}
THROTTLE=1
DEP_JOBIDS=""
NUM_PARA=0
OUTPUT_DIR="test-results-data/sched-scalability"
TAP_RESULTS=false
EXP_ID=$(date +%s).$(od -N 4 -t uL -An /dev/urandom | tr -d " ")
EXP_INST="instances"
EXP_FILE=${EXP_INST}.${EXP_ID}

# Utility
DRY_RUN=false

debug_params () {
    echo "========= scheduling param space ================"
    echo "sched_policy_params: ${sched_policy_params}"
    echo "sched_queue_depths: ${sched_queue_depths}"
    echo "sched_delay: ${sched_delay}"
    echo "num_jobs_params: ${num_jobs_params}"
    echo "sizing_policy_param: ${sizing_policy_params}"
    echo "codes_params: ${codes_params}"
    echo "========= scheduling scalability space =========="
    echo "nnodes_params: ${nnodes_params}"
    echo "bpn_params: ${bpn_params}"
    echo "duration: ${duration}"
    echo "==================== config ====================="
    echo "RM: ${RM}"
    echo "WL: ${WL}"
    echo "PRECEDENCE: ${PRECEDENCE}"
    echo "THROTTLE: ${THROTTLE}"
    echo "OUTPUT_DIR: ${OUTPUT_DIR}"
    echo "TAP_RESULTS: ${TAP_RESULTS}"
    echo "EXP_ID: ${EXP_ID}"
    echo "EXP_INST: ${EXP_INST}"
    echo "EXP_FILE: ${EXP_FILE}"
    echo ""
}

print_usage () {
    cat <<EOF
usage: perfexplore.sh [OPTIONS] FLUX_PATH|EXP_ID

Explore flux-sched's performance/scalability space. It varies each
and all of the testing parameters and runs each configuration as a
flux instance launched in an allocation created by the native
resource manager and scheduler (only SLURM and MOAB are supported
for now).

Write the performance data into test-results-data/sched-scalability
directory or the directory specified with -o or --output-dir option,
when each instance successfully completes.
The file naming scheme of these data themselves is described in the
Performance Data File Naming Scheme section below.

Exit immediately after all instances are submitted.
Users can see the success and/or failure by running this program
with -T or --tap-results option with EXP_ID as the argument.
Please ensure that all of the instances have completed before use
-T. Results are printed in Test Anything Protocol (TAP).

positional arguments:
  FLUX_PATH                path to the root installation of flux
  EXP_ID                   unique ID with which this program
                             associates the experiment (printed by
                             this program at the end).

optional arguments  (scheduling parameters space to explore):
 -p, --sched-policies=str  white-space-separated string to define
                             flux scheduling policies to explore.
                             "FCFS EASY" to explore FCFS and EASY
                             backfill. (default to all available
                             policies: ${sched_policy_params})
 -q, --queue-depths=str    white-space-separated queue depth values
                             each must be greater than 0
                             (default: ${sched_queue_depths})
 -d, --delay=str           white-space-separated delay scheduling
                             space string, e.g., "true false".
                             (default: ${sched_delay})
 -j, --njobs=str           white-space-separated job counts space
                             each must be greater than 1000
                             (default: ${num_jobs_params})
 -s, --job-sizing=str      white-space-separated job sizing
                             policies (default to all available
                             policies: ${sizing_policy_params})
 -c, --codes               white-space-separated command names
                             (default to all available codes:
                             ${codes_params})

optional arguments (sched scalability space to explore):
 -N, --nnodes=str          white-space-separated compute-node counts
                             each must be greater than 0
                             (default: ${nnodes_params})
 -B, --nbrokers=val        num of brokers to launch on each node
                             (currently only 1 broker is supported)
                             (default: ${bpn_params})

optional arguments (performance target):
 -m, --makespan=secs       wall clock time (secs) within which each
                             run must complete
                             (default: ${duration})

optional arguments (configuration control):
 -R, --resource-mgr=rm     native resource mgr (only SLURM for now)
                             (default: ${RM})
 -W, --workload-mgr=wm     native workload mgr (only MOAB for now)
                             (default: ${WL})
 -P, --precedence=str      order in which each parameter space is
                             explored. str must be an ordered set of
                             one or more parameter space coded by
                             their short commandline options (e.g.,
                             "N p" will vary all p parameter space
                             before varying N parameter to the next
                             (default: ${PRECEDENCE})
 -l, --limit=val           limit the number of simultaneously running
                             instances to val
 -o, --output-dir=dir      directory to dump perf data (default:
                             ${OUTPUT_DIR})
 -T, --tap-results         print success and/or failure in TAP
                             the positional argument must be EXP_ID

optional arguments (utilities):
 -h, --help                print this message
 -y, --dry-run             don't run instances (only print submit
                             commands)

Performance Data File Naming Scheme:
  Create two performance data files per instance:
     Suffix ending with in.stats contains perf per each 1000 jobs
     Suffix ending with ov.stats contains overall performance
 Prefix concatenates each parameter of an instance as:
     W.R.NxB.s.c.p.q.d.j.m, where each letter corresponding to a
     short option above is replaced with the value used for the
     instance.
EOF
    exit 1
}

member () {
    local SET=${1}
    local ELEM=${2}
    local found=""
    for s in ${SET};
    do
        if  test "${s}" = "${ELEM}";
        then
            return 0
        fi 
    done
    return 1
}

valid_precedence () {
    local P=${1}
    local REF_P=${2}
    for p in ${P};
    do
        member "${REF_P}" ${p}
        if test $? -eq 1;
        then
            return 1
        fi
    done
    return 0
}

precedence () {
    local P=${1}
    local REF_P=${2}
    local RET_P=${P}

    valid_precedence "${P}" "${REF_P}" 
    if test $? -ne 0; 
    then
        return 1
    fi

    for rp in ${REF_P};
    do 
        member "${P}" "${rp}"
        if test $? -eq 1;
        then
            RET_P="${RET_P} ${rp}"
        fi
    done
    echo ${RET_P}
    return 0
}

params () {
    local pclass=${1}
    local pset=""
    case ${pclass} in
        N) pset=${nnodes_params} ;; 
        B) pset=${bpn_params} ;; 
        c) pset=${codes_params} ;; 
        s) pset=${sizing_policy_params} ;; 
        p) pset=${sched_policy_params} ;; 
        q) pset=${sched_queue_depths} ;; 
        d) pset=${sched_delay} ;; 
        j) pset=${num_jobs_params} ;; 
        * ) echo <&2 "Unknown precedence letter ${pclass}" 
    esac    
    echo "${pset}"
}

expenv () {
    local pclass=${1}
    local param=${2}

    case ${pclass} in
        N) export SCAL_TST_NODES=${param} ;;
        B) export SCAL_TST_BROKERS_PER_NODE=${param} ;;
        c) export SCAL_TST_SLEEP_CMD=${param} ;;
        s) export SCAL_TST_SIZING_POLICY=${param} ;;
        p) export SCAL_TST_SCHED_POLICY=${param} ;;
        q) export SCAL_TST_QUEUE_DEPTH=${param} ;;
        d) export SCAL_TST_DELAY=${param} ;;
        j) export SCAL_TST_NUM_JOBS=${param} ;;
        *) echo <&2 "Unknown precedence letter ${pclass}" ;;
    esac    
} 

fake_id=1234
debug_comment () {
    local sched="SCAL_TST_SCHED_POLICY=${SCAL_TST_SCHED_POLICY}" 
    sched="${sched};SCAL_TST_QUEUE_DEPTH=${SCAL_TST_QUEUE_DEPTH}"
    sched="${sched};SCAL_TST_DELAY=${SCAL_TST_DELAY}"
    sched="${sched};SCAL_TST_SIZING_POLICY=${SCAL_TST_SIZING_POLICY}"
    sched="${sched};SCAL_TST_SLEEP_CMD=${SCAL_TST_SLEEP_CMD}"
    sched="${sched};SCAL_TST_NUM_JOBS=${SCAL_TST_NUM_JOBS}"
    local conf="SCAL_TST_NODES=${SCAL_TST_NODES}"
    conf="${conf};SCAL_TST_BROKERS_PER_NODE=${SCAL_TST_BROKERS_PER_NODE}"
    echo "${sched};${conf}"
}

submit_instance () {
    local comment=$(debug_comment)
    local dep_id=""
    local spec="nodes=${SCAL_TST_NODES},walltime=${SCAL_TST_TARGET}"

    if test "${NUM_PARA}" != "${THROTTLE}";
    then
        echo "msub -V -l ${spec} sched-scale-wrap.sh ### ${comment}"
        NUM_PARA=$((NUM_PARA+1))
        if test "${DRY_RUN}" = "false";
        then
            dep_id=$(msub -V -l ${spec} sched-scale-wrap.sh) 
            dep_id=$(echo $dep_id|tr -d '\n')
        else
            dep_id=${fake_id}
            fake_id=$((fake_id+1))
        fi
        echo ${dep_id} >> ${EXP_FILE}
        DEP_JOBID="${DEP_JOBID} ${dep_id}"
    else
        dep_id=$(echo ${DEP_JOBID} | cut -d ' ' -f1)
        spec="${spec},depend=${dep_id}"

        echo "msub -V -l ${spec} sched-scale-wrap.sh ### ${comment}"
        if test "${DRY_RUN}" = "false";
        then
            dep_id=$(msub -V -l ${spec} sched-scale-wrap.sh) 
            dep_id=$(echo $dep_id|tr -d '\n')
        else
            dep_id=${fake_id}
            fake_id=$((fake_id+1))
        fi
        echo ${dep_id} >> ${EXP_FILE}

        if test ${THROTTLE} != 1;
        then
            DEP_JOBID=$(echo ${DEP_JOBID} | cut -d ' ' -f2-)
        else
            DEP_JOBID=""
        fi
        DEP_JOBID="${DEP_JOBID} ${dep_id}"
    fi
}

explore () {
    local P=${1}
    local p=""
    local pclass=""

    if test -z "${P}";
    then
        submit_instance 
        return 0
    fi
    pclass=${P:0:1}
    for p in $(params ${pclass});
    do
        expenv ${pclass} ${p}
        explore "${P:2}" 
    done
    return 0
}

print_tap_results () {
    file=${EXP_INST}.${1}
    if ! test -f ${file};    
    then
        echo <&2 "Error: experiment file doesn't exist"
        return 1
    fi

    echo "=================================================================="
    echo " Querying test results for EXP_ID=${1}"
    echo "=================================================================="

    while read -r line; do
       cat slurm-${line}.out
       if test $? -ne 0;
       then
           echo <&2 "Error: slurm.${file} doesn't exist"
           return 1
       fi
    done < ${file}

    echo "=================================================================="
    echo " Done the query. EXP_ID for this experiment: ${EXP_ID}"
    echo "=================================================================="
    return 0
}


############################################################################
#                                 Main                                     #
############################################################################

OPTS=$(getopt -o ${SHORT_OPTSTR} -l ${LONG_OPTSTR} -n ${SCRIPT_NM} -- "$@")
if test "$?" != 0;
then
    echo <&2 "Error: Failed parsing options." >&2
    print_usage 
fi
eval set -- ${OPTS}
while true;
do
    case "$1" in
        -p | --sched-policies ) sched_policy_params="$2"; shift; shift ;;
        -q | --queue-depths ) sched_queue_depths="$2"; shift; shift ;;
        -d | --delay ) sched_delay="$2"; shift; shift ;;
        -j | --njobs ) num_jobs_params="$2"; shift; shift ;;
        -s | --job-sizing ) sizing_policy_params="$2"; shift; shift ;;
        -c | --codes ) codes_params="$2"; shift; shift ;;
        -N | --nnodes ) nnodes_params="$2"; shift; shift ;;
        -B | --nbrokers ) bpn_params="$2"; shift; shift ;;
        -m | --makespan ) duration="$2"; shift; shift ;;
        -R | --resource-mgr ) RM="$2"; shift; shift ;;
        -W | --workload-mgr ) WL="$2"; shift; shift ;;
        -P | --precedence ) PRECEDENCE="$2"; shift; shift ;;
        -l | --limit ) THROTTLE="$2"; shift; shift ;;
        -o | --output-dir ) OUTPUT_DIR="$2"; shift; shift ;;
        -T | --tap-results ) TAP_RESULTS=true; shift ;;
        -h | --help ) print_usage; shift ;;
        -y | --dry-run ) DRY_RUN=true; shift ;;
        -- ) shift; break ;;
        * ) break ;;
    esac
done


posarg=${1:-0}

if test $# -lt 1; 
then
    echo <&2 "Error: FLUX_PATH or EXP_ID not given"
    print_usage
fi

if test "${TAP_RESULTS}" = "true";
then
    print_tap_results ${posarg}
    exit $?
fi

if ! test -f "${posarg}/bin/flux"; then
    echo <&2 "Error: ${posarg}/bin/flux doesn't exist"
    print_usage
else
  fluxbin=$(readlink -e "${posarg}/bin/flux")
  fluxdir=$(dirname ${fluxbin})
  export PATH=${fluxdir}:${PATH}
fi

script_path=$(readlink -e $0)
export SCAL_TST_BASEPATH=$(dirname $script_path)
export SCAL_TST_WLM=MOAB
export SCAL_TST_RM=SLURM
export SCAL_TST_TARGET=${duration}
export OUTPUT_DIR

FQ_PRECEDENCE=$(precedence "${PRECEDENCE}" "${REF_PRECEDENCE}")
if test $? -ne 0;
then 
    echo <&2 "Error: Invalid PRECEDENCE? (${PRECEDENCE})" 
    print_usage
fi

spp=$(echo ${sched_policy_params} | wc -w)
sqd=$(echo ${sched_queue_depths} | wc -w)
sd=$(echo ${sched_delay} | wc -w)
njp=$(echo ${num_jobs_params} | wc -w)
szpp=$(echo ${sizing_policy_params} | wc -w)
cop=$(echo ${codes_params} | wc -w)
np=$(echo ${nnodes_params} | wc -w)
bpnp=$(echo ${bpn_params} | wc -w)
dim=$((spp*sqd*sd*njp*szpp*cop*np*bpnp))

touch ${EXP_FILE}
echo "=================================================================="
echo " Submitting ${dim} flux instances to explore its performance space"
echo "=================================================================="

explore "${FQ_PRECEDENCE}" 

echo "=================================================================="
echo " Done submitting. EXP_ID for this experiment: ${EXP_ID}"
echo "=================================================================="

# vi: ts=4 sw=4 expandtab
