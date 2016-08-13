all: mpiusleep

mpiusleep: mpiusleep.c
	mpicc -O0 $^ -o $@

.PHONY: clean

clean:
	rm -rf trash-directory.t0001-sched-scale *.log mpiusleep
