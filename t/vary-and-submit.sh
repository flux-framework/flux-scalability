#!/bin/sh
#set -x

print_usage() {
  echo <&2 "Usage: vary-and-submit FLUX_INSTALL_BASE_PATH"
  exit 1
}

if test "$#" -ne 1; then
  print_usage
elif ! test -f "${1}/bin/flux"; then
  echo <&2 "${1}/bin/flux doesn't exist"
  print_usage
else 
  fluxbin=$(readlink -e "${1}/bin/flux")
  fluxdir=$(dirname ${fluxbin})
  export PATH=${fluxdir}:${PATH}
fi 

#                                                         #
#== Begin variable definitions here for our param space ==#
#                                                         #
sched_policy_params="FCFS" 
#sched_policy_params="WRECKRUN" 
#sched_policy_params="FCFS EASY CONSERVATIVE HYBRID100" 
nnodes_params="2 32"
#nnodes_params="2 4 8 16 32"
bpn_params=1 #TODO: add more here for phase II and beyond 
#mpi_params="usleep mpiusleep"
mpi_params="usleep" 
#sizing_policy_param="unit half power_2"
sizing_policy_param="unit"
#num_jobs_params="2000 5000 10000 20000 50000 100000"
num_jobs_params="10000"
#duration=10800 # unit is second; thus 3 hours
duration=43200 # unit is second; thus 3 hours
#                                                         #
#== End variable definitions here for our parameter space #
#                                                         #

dep_id=0
script_path=$(readlink -e $0)
export SCAL_TST_BASEPATH=$(dirname $script_path)

#
# Ugly 5-deep nested loop
#
export SCAL_TST_WLM=MOAB
export SCAL_TST_RM=SLURM
#== vary nodes
for n_p in ${nnodes_params};
do
  export SCAL_TST_NODES=${n_p}
  export SCAL_TST_BROKERS_PER_NODE=${bpn_params}
  #== vary mpi vs. non-mpi sleep
  for mpi_p in ${mpi_params};
  do
    export SCAL_TST_SLEEP_CMD=${mpi_p}
    #== vary job sizing policy
    for sz_p in ${sizing_policy_param}; 
    do
      export SCAL_TST_SIZING_POLICY=${sz_p}
      #== vary scheduling policy
      for sched_p in ${sched_policy_params};
      do
        export SCAL_TST_SCHED_POLICY=${sched_p}
        #== vary job count 
        for numj_p in ${num_jobs_params};
        do
          export SCAL_TST_NUM_JOBS=${numj_p}
          export SCAL_TST_TARGET=${duration}

          spec="nodes=${n_p},walltime=${duration}"
          if test "$dep_id" != "0"; then
              spec="${spec},depend=${dep_id}"
          fi

          #                                               #
          #== Submit a job as our experimental point here #
          #                                               #
          echo "msub -V -l ${spec} sched-scale-wrap.sh"
          dep_id=$(msub -V -l ${spec} sched-scale-wrap.sh)
          #echo "msub -V -l ${spec} wreck-scale-wrap.sh"
          #dep_id=$(msub -V -l ${spec} wreck-scale-wrap.sh)
          dep_id=$(echo $dep_id|tr -d '\n')
        done
      done
    done
  done
done

# vi: ts=4 sw=4 expandtab

