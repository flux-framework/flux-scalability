## Scalability testing rig for flux-sched

*NOTE: This is work in progress.*

This directory and its subdirectories contain a scalability testing rig for 
`flux-sched.` We start this effort as a means to execute our CTS-1 `flux-sched` 
testing plan described in distribution issue
[#14](https://github.com/flux-framework/distribution/issues/14). While our 
ultimate goal is to extend this to provide an automatic performance/scalability 
regression test suite for various Flux projects, it is currently limited to 
support the Phase I of our CTS-1 testing plan . The exploration space consists of 
6 dimensions: {NODES} x {BPN} x {Flux Scheduling Policy} x {MPI vs. Non-MPI 
sleep} x {Num of Flux Jobs} x {Flux Job Sizing Policy}. `vary-and-submit.sh` 
script hard-codes the ranges for there parameters. 


- **NODES**: Number of compute nodes to use;
- **BPN**: Brokers per node (currently only set to 1);
- **Flux Scheduling Policy**: FCFS, EASY, CONSERVATIVE, HYBRID100;
- **MPI vs. Non-MPI sleep**: Sleep with or without `MPI_Init()` and 
`MPI_Finalize()`;
- **Num of Flux Jobs**: Number of jobs to submit, schedule and run in the flux 
sesion with a pretty loose performance target (3 hours);
- **Flux Job Sizing Policy**: unit (each job requesting 1 core), half (1/2 NODES 
cores), and power_2 (powers-of-two cores with wrapping)



One can run a full experiment on an LC system running MOAB/SLURM as follows:

1. Typing in `make` builds `mpiusleep`
2. Typing in `vary-and-submit.sh FLUX_INSTALL_BASEPATH` iterates through this 
parameter space and submits each point job in this space into MOAB via `msub`
3. Each MOAB job will then use a parameterized sharness test script 
(`t0001-sched-scale.t`) such that the batchjob output will contain the TAP 
results of this shareness test: e.g., 

    ```
ok 1 - sched at MOAB.SLURM.00000002.00002Nx01B.unit.usleep.00002000.10800: size 
ok 2 - sched at MOAB.SLURM.00000002.00002Nx01B.unit.usleep.00002000.10800: sched 
ok 3 - sched at MOAB.SLURM.00000002.00002Nx01B.unit.usleep.00002000.10800: BPN 
ok 4 - sched at MOAB.SLURM.00000002.00002Nx01B.unit.usleep.00002000.10800: run 
# passed all 4 test(s)
1..4
ok 1 - sched at MOAB.SLURM.00000004.00004Nx01B.unit.usleep.00002000.10800: size 
ok 2 - sched at MOAB.SLURM.00000004.00004Nx01B.unit.usleep.00002000.10800: sched 
ok 3 - sched at MOAB.SLURM.00000004.00004Nx01B.unit.usleep.00002000.10800: BPN 
ok 4 - sched at MOAB.SLURM.00000004.00004Nx01B.unit.usleep.00002000.10800: run 
# passed all 4 test(s)
1..4
```
These MOAB jobs will run one at a time through linear dependencies.
4. When each MOAB job successfully completes, it stores two coarse-grained 
performance data files into `test-results-data/sched-scalability` directory. The 
file names are composed of the values used for the experimental parameters as 
described above. 
5. One can post-process these raw performance data files to characterize the 
peformance and scalability of `flux-sched` and also `flux-core` to some extent. 
In the futrue, we may automate ways to load these files into a mysql database and 
come up with various SQL queries.


