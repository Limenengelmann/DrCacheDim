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

extern const size_t size1;
extern const size_t reps1;
extern const size_t size2;
extern const size_t reps2;
extern const size_t size3;
extern const size_t reps3;
extern int64_t generate_memrefs(char* A);

int main(int argc, char** argv) {
    //srand(0);

    //const size_t size1 = (size_t) atoi(argv[L1_SIZE]);
    //const size_t reps1 = (size_t) atoi(argv[L1_REPS]);
    //const size_t size2 = (size_t) atoi(argv[L2_SIZE]);
    //const size_t reps2 = (size_t) atoi(argv[L2_REPS]);
    //const size_t size3 = (size_t) atoi(argv[L3_SIZE]);
    //const size_t reps3 = (size_t) atoi(argv[L3_REPS]);

    register int8_t *A, *B, *C, *D;
    // allocate array
    A = malloc(size3 + LINEWIDTH);
    if (A == NULL)
        handle_error("malloc failed:");
    //printf("A: %p, ", A);
    A += LINEWIDTH - (uintptr_t) A % LINEWIDTH; // align to LINEWIDTH
    D = B = C = A;                                           
    //printf("aligned: %p\n", A);
                                                
    // use systemcalls to create random array A of size size3
    // so it doesnt show up in the memtrace since it happens in Kernel space
    FILE* rnd = fopen("/dev/random", "r");
    if (rnd == NULL)
        handle_error("fopen failed:");
    if (fread((void *)A, sizeof(char), size3, rnd) != size3)
        handle_error("fread failed:");
    fclose(rnd);

    generate_memrefs(A);
    /*
    register int64_t t = 0;
    for(size_t r3=0; r3<reps3; r3++) {
        //B = A + rand() % (size3 / size2);
        C = B;
        for(size_t r2=0; r2<reps2; r2++) {
            //C = B + rand() % (size2 / size1);
            D = C;
            for(size_t r1=0; r1<reps1; r1++) {
                t += *D;
                D += LINEWIDTH;
                if (D >= C + size1)
                    D = C;
            }
            C += size1;
            if (C >= B + size2)
                C = B;
        }
        B += size2;
        if (B >= A + size3)
            B = A;
    }
    */

    //free(A);
}
