#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <mpi.h>

int main (int argc, char *argv[])
{
    unsigned int usec = 0;
    MPI_Init (&argc, &argv);
    if (argc != 2) {
        fprintf (stderr, "Usage: mpiusleep NUMBER\n");
        fprintf (stderr, "  sleep some number of microseconds\n");
        MPI_Finalize ();
        exit (1);
    }
    usec = (unsigned int) atoi (argv[1]);
    usleep (usec);
    MPI_Finalize ();
    return EXIT_SUCCESS;
}
