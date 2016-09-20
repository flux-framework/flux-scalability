all: mpiusleep

mpiusleep: mpiusleep.c
	mpicc -O0 $^ -o $@

.PHONY: clean

clean:
	rm -rf trash-directory* *.log mpiusleep instances* slurm-* t0001-sched-scale-*
