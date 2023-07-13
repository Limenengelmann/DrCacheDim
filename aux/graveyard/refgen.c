#include <stdint.h>
#include <stdlib.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <string.h>
#include <stdio.h>
#include <unistd.h>

#define L1_SIZE 1
#define L1_REPS 2
#define L2_SIZE 3
#define L2_REPS 4
#define L3_SIZE 5
#define L3_REPS 6

#define LINEWIDTH 64

#define handle_error(msg) \
    do { perror(msg); exit(EXIT_FAILURE); } while (0)

extern const unsigned int size1;
extern const unsigned int reps1;
extern const unsigned int size2;
extern const unsigned int reps2;
extern const unsigned int size3;
extern const unsigned int reps3;
extern unsigned int generate_memrefs(char* A);

int main(int argc, char** argv) {
    //srand(0);

    //const size_t size1 = (size_t) atoi(argv[L1_SIZE]);
    //const size_t reps1 = (size_t) atoi(argv[L1_REPS]);
    //const size_t size2 = (size_t) atoi(argv[L2_SIZE]);
    //const size_t reps2 = (size_t) atoi(argv[L2_REPS]);
    //const size_t size3 = (size_t) atoi(argv[L3_SIZE]);
    //const size_t reps3 = (size_t) atoi(argv[L3_REPS]);

    register char *A;
    // allocate array
    A = malloc(size3 + LINEWIDTH);
    if (A == NULL)
        handle_error("malloc failed:");
    //printf("A: %p, ", A);
    A += LINEWIDTH - (uintptr_t) A % LINEWIDTH; // align to LINEWIDTH
    //printf("aligned: %p\n", A);
                                                
    // use systemcalls to create random array A of size size3
    // so it doesnt show up in the memtrace since it happens in Kernel space
    FILE* rnd = fopen("/dev/random", "r");
    if (rnd == NULL)
        handle_error("fopen failed:");
    if (fread((void *)A, sizeof(char), size3, rnd) != size3)
        handle_error("fread failed:");
    fclose(rnd);

    return generate_memrefs(A);
    //free(A);
}
