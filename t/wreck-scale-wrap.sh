#!/bin/sh

if test -z ${SCAL_TST_BASEPATH}; then
    echo <&2 "SCAL_TST_BASEPATH envVar must be passed"
    exit 1
fi

cd ${SCAL_TST_BASEPATH}
# SLURM_JOBID needs to be WLM/RM ineutral later on
ln -s t0002-wreck-scale.t t0002-wreck-scale-${SLURM_JOBID}.t
./t0002-wreck-scale-${SLURM_JOBID}.t #--verbose

# vi: ts=4 sw=4 expandtab
