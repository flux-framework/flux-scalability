#!/bin/sh

if test -z ${SCAL_TST_BASEPATH}; then
    echo <&2 "SCAL_TST_BASEPATH envVar must be passed"
    exit 1
fi

cd ${SCAL_TST_BASEPATH}
ln -s t0001-sched-scale.t t0001-sched-scale-${SLURM_JOBID}.t
./t0001-sched-scale-${SLURM_JOBID}.t #--debug #--verbose

# vi: ts=4 sw=4 expandtab
