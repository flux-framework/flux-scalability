## PerfExplore: Explore Performance and Scalability of Flux
### 1. Background
**Flux PerfExplore** is designed to explore the performance and scalability space
of Flux. It varies each and all of the testing parameters and runs each
configuration as a Flux instance launched in an allocation created by the native
resource manager and scheduler.

This project is work in progress as we started this effort as a means
to execute our CTS-1 `flux-sched` testing plan described in distribution issue
[#14](https://github.com/flux-framework/distribution/issues/14). However, the
ultimate goal of **Flux PerfExplore** is to provide an automatic performance
and scalability regression test suite for the various Flux projects. 

### 2. Exploration Space
The exploration space currently consists of 8 dimensions relevant in particular
to scheduling: {NODES} x {BPN} x
{Flux Scheduling Policies} x {Scheduling Queue Depths} x {Schduling Delay} x
{MPI vs. Non-MPI usleep} x {Flux Job Counts} x {Flux Job Sizing Policies}.

- **NODES**: Compute node counts to explore;
- **BPN**: Brokers per node counts to explore (currently only set to 1);
- **Flux Scheduling Policies**: Scheduling policies (currently, FCFS, EASY,
    CONSERVATIVE, and HYBRID100);
- **Scheduling Queue Depths**: Scheduler's pending-queue depth values
     to explore; each value (val) is translated into
     the `sched-params=queue-depth=val` scheduler load option;
- **Scheduling Delay**: Scheduler's delay scheduling optimization
     to explore (i.e., "true", "false" or "true false" -- each value (val)
     of this space is used to explore `sched-params=delay-sched=val`);
- **MPI vs. Non-MPI usleep**: Sleep with or without `MPI_Init()` and 
    `MPI_Finalize()`;
- **Flux Job Counts**: Flux job counts space to explore. Each count value
    is the total number of jobs submited to the testing instance;
- **Flux Job Sizing Policies**: Flux job size geometries to explore (i.e.,
    unit (each job requesting 1 core), half (1/2 NODES cores), and power_2
    (core count increases in powers-of-two, then wraps when it reaches it
    its node count)).

### 2. Driver

`perfexplore.sh` is the driver which allows testers to pass in a range for each
parameter space to explore. Once invoked, it computes each and all experiment
points and submits them to the the native resource manager and scheduler. Once all
instances are submitted, `perfexplore.sh` immediately exits with the following
messages.


```
==================================================================
 Done submitting. EXP_ID for this experiment: 1473974067.1097345282
==================================================================
```

Here, `integer.integer` is the unique experiment ID (`EXP_ID`) with which
**PerfExplore** associates the experiment. The first integer is
the epoch since 1970-01-01 00:00:00 UTC and the second is a random number.
Users can query the success and/or
failure of each test instance by running `perfexplore.sh` with `-T` or
`--tap-results` option with `EXP_ID` as its positional argument. The success or
failure criteria of each instance is whether it has successfully completed
within the target wall-clock time. Thus, users must ensure that all of the
instances have completed before use `-T`. Results are printed in Test Anything
Protocol (TAP).

Even though the driver exits after the submits, as each instance successfully
completes, its performance data files are stored in the specified directory for
later inspection.

### 3. Performance Data Files
Each experiment stores the performance data files into
`test-results-data/sched-scalability` or the directory specified with `-o` or
`--output-dir` option. The following file-naming scheme is used.

- Create two performance data files per instance:
     - Suffix ending with in.stats contains perf per each 1000 jobs
     - Suffix ending with ov.stats contains overall performance
- Prefix concatenates each parameter of an instance as: 
     - `W.R.NxB.s.c.p.q.d.j.m`, where each letter corresponding to a
     short option above is replaced with the value used for the
     instance.


### 4. Example Experiment
Running a **PerfExplore** experiment on LLNL's LC machine called `hype`:

```
hype356{dahn}93: perfexplore.sh --nnodes="2 4 8" --job-sizing="half" --codes="usleep" --sched-policies="FCFS" --njobs="1000 2000" ../../flux-stage/

==================================================================
 Submitting 6 flux instances to explore its performance space
==================================================================
msub -V -l nodes=2,walltime=10800 sched-scale-wrap.sh
msub -V -l nodes=2,walltime=10800,depend=20892 sched-scale-wrap.sh ### debug comments
msub -V -l nodes=4,walltime=10800,depend=20893 sched-scale-wrap.sh ### debug comments
msub -V -l nodes=4,walltime=10800,depend=20894 sched-scale-wrap.sh ### debug comments
msub -V -l nodes=8,walltime=10800,depend=20895 sched-scale-wrap.sh ### debug comments
msub -V -l nodes=8,walltime=10800,depend=20896 sched-scale-wrap.sh ### debug comments
==================================================================
 Done submitting. EXP_ID for this experiment: 1473974919.3631007319
==================================================================

# Each msub command represents a test intance with a specific combination of parameters being explored
# debug comments will show the values used for these parameters 
# Once all of these jobs are finished
```


### 5. Querying the PerfExplore experiment PASS/FAIL results

On the above experiment (EXP_ID: 1473974919.3631007319):

```
hype356{dahn}94: perfexplore.sh --tap-results 1473974919.3631007319

==================================================================
 Querying test results for EXP_ID=1473974919.3631007319
==================================================================
ok 1 - sched at MOAB.SLURM.00000002.00002Nx01B.half.usleep.FCFS.QD16.DELAYtrue.00001000.10800: size matches config
ok 2 - sched at MOAB.SLURM.00000002.00002Nx01B.half.usleep.FCFS.QD16.DELAYtrue.00001000.10800: sched module loaded
ok 3 - sched at MOAB.SLURM.00000002.00002Nx01B.half.usleep.FCFS.QD16.DELAYtrue.00001000.10800: persist fs attr matches
ok 4 - sched at MOAB.SLURM.00000002.00002Nx01B.half.usleep.FCFS.QD16.DELAYtrue.00001000.10800: BPN matches config
ok 5 - sched at MOAB.SLURM.00000002.00002Nx01B.half.usleep.FCFS.QD16.DELAYtrue.00001000.10800: run 1000 jobs in 10800 secs
# passed all 5 test(s)
1..5
ok 1 - sched at MOAB.SLURM.00000002.00002Nx01B.half.usleep.FCFS.QD16.DELAYtrue.00002000.10800: size matches config
ok 2 - sched at MOAB.SLURM.00000002.00002Nx01B.half.usleep.FCFS.QD16.DELAYtrue.00002000.10800: sched module loaded
ok 3 - sched at MOAB.SLURM.00000002.00002Nx01B.half.usleep.FCFS.QD16.DELAYtrue.00002000.10800: persist fs attr matches
ok 4 - sched at MOAB.SLURM.00000002.00002Nx01B.half.usleep.FCFS.QD16.DELAYtrue.00002000.10800: BPN matches config
ok 5 - sched at MOAB.SLURM.00000002.00002Nx01B.half.usleep.FCFS.QD16.DELAYtrue.00002000.10800: run 2000 jobs in 10800 secs
# passed all 5 test(s)
1..5
ok 1 - sched at MOAB.SLURM.00000004.00004Nx01B.half.usleep.FCFS.QD16.DELAYtrue.00001000.10800: size matches config
ok 2 - sched at MOAB.SLURM.00000004.00004Nx01B.half.usleep.FCFS.QD16.DELAYtrue.00001000.10800: sched module loaded
ok 3 - sched at MOAB.SLURM.00000004.00004Nx01B.half.usleep.FCFS.QD16.DELAYtrue.00001000.10800: persist fs attr matches
ok 4 - sched at MOAB.SLURM.00000004.00004Nx01B.half.usleep.FCFS.QD16.DELAYtrue.00001000.10800: BPN matches config
ok 5 - sched at MOAB.SLURM.00000004.00004Nx01B.half.usleep.FCFS.QD16.DELAYtrue.00001000.10800: run 1000 jobs in 10800 secs
# passed all 5 test(s)
1..5
ok 1 - sched at MOAB.SLURM.00000004.00004Nx01B.half.usleep.FCFS.QD16.DELAYtrue.00002000.10800: size matches config
ok 2 - sched at MOAB.SLURM.00000004.00004Nx01B.half.usleep.FCFS.QD16.DELAYtrue.00002000.10800: sched module loaded
ok 3 - sched at MOAB.SLURM.00000004.00004Nx01B.half.usleep.FCFS.QD16.DELAYtrue.00002000.10800: persist fs attr matches
ok 4 - sched at MOAB.SLURM.00000004.00004Nx01B.half.usleep.FCFS.QD16.DELAYtrue.00002000.10800: BPN matches config
ok 5 - sched at MOAB.SLURM.00000004.00004Nx01B.half.usleep.FCFS.QD16.DELAYtrue.00002000.10800: run 2000 jobs in 10800 secs
# passed all 5 test(s)
1..5
ok 1 - sched at MOAB.SLURM.00000008.00008Nx01B.half.usleep.FCFS.QD16.DELAYtrue.00001000.10800: size matches config
ok 2 - sched at MOAB.SLURM.00000008.00008Nx01B.half.usleep.FCFS.QD16.DELAYtrue.00001000.10800: sched module loaded
ok 3 - sched at MOAB.SLURM.00000008.00008Nx01B.half.usleep.FCFS.QD16.DELAYtrue.00001000.10800: persist fs attr matches
ok 4 - sched at MOAB.SLURM.00000008.00008Nx01B.half.usleep.FCFS.QD16.DELAYtrue.00001000.10800: BPN matches config
ok 5 - sched at MOAB.SLURM.00000008.00008Nx01B.half.usleep.FCFS.QD16.DELAYtrue.00001000.10800: run 1000 jobs in 10800 secs
# passed all 5 test(s)
1..5
ok 1 - sched at MOAB.SLURM.00000008.00008Nx01B.half.usleep.FCFS.QD16.DELAYtrue.00002000.10800: size matches config
ok 2 - sched at MOAB.SLURM.00000008.00008Nx01B.half.usleep.FCFS.QD16.DELAYtrue.00002000.10800: sched module loaded
ok 3 - sched at MOAB.SLURM.00000008.00008Nx01B.half.usleep.FCFS.QD16.DELAYtrue.00002000.10800: persist fs attr matches
ok 4 - sched at MOAB.SLURM.00000008.00008Nx01B.half.usleep.FCFS.QD16.DELAYtrue.00002000.10800: BPN matches config
ok 5 - sched at MOAB.SLURM.00000008.00008Nx01B.half.usleep.FCFS.QD16.DELAYtrue.00002000.10800: run 2000 jobs in 10800 secs
# passed all 5 test(s)
1..5
==================================================================
 Done the query. EXP_ID for this experiment: 1473975549.339076686
==================================================================

```

### 5. Inspecting Performance Data Files
 
```
hype356{dahn}103: ls test-results-data/sched-scalability/ 
MOAB.SLURM.00000002.00002Nx01B.half.usleep.FCFS.QD16.DELAYtrue.00001000.10800.in.stats
MOAB.SLURM.00000004.00004Nx01B.half.usleep.FCFS.QD16.DELAYtrue.00002000.10800.in.stats
MOAB.SLURM.00000002.00002Nx01B.half.usleep.FCFS.QD16.DELAYtrue.00001000.10800.ov.stats
MOAB.SLURM.00000004.00004Nx01B.half.usleep.FCFS.QD16.DELAYtrue.00002000.10800.ov.stats
MOAB.SLURM.00000002.00002Nx01B.half.usleep.FCFS.QD16.DELAYtrue.00002000.10800.in.stats
MOAB.SLURM.00000008.00008Nx01B.half.usleep.FCFS.QD16.DELAYtrue.00001000.10800.in.stats
MOAB.SLURM.00000002.00002Nx01B.half.usleep.FCFS.QD16.DELAYtrue.00002000.10800.ov.stats
MOAB.SLURM.00000008.00008Nx01B.half.usleep.FCFS.QD16.DELAYtrue.00001000.10800.ov.stats
MOAB.SLURM.00000004.00004Nx01B.half.usleep.FCFS.QD16.DELAYtrue.00001000.10800.in.stats
MOAB.SLURM.00000008.00008Nx01B.half.usleep.FCFS.QD16.DELAYtrue.00002000.10800.in.stats
MOAB.SLURM.00000004.00004Nx01B.half.usleep.FCFS.QD16.DELAYtrue.00001000.10800.ov.stats
MOAB.SLURM.00000008.00008Nx01B.half.usleep.FCFS.QD16.DELAYtrue.00002000.10800.ov.stats

```

### 6. More Information
More information about PerfExplore's options can be found by typing in `perfexplore --help`.
