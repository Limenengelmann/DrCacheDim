#include "matrix.h"

int main(int argc, char** argv) {
    if (argc < 2) {
        printf("Usage: matmul m\n");
        return -1;
    }

    int m = atoi(argv[1]);
    mtype* A = (mtype*) malloc(sizeof(mtype)*m*m);
    store_t stypeA = ROWMAJOR;
    mtype* B = (mtype*) malloc(sizeof(mtype)*m*m);
    store_t stypeB = COLMAJOR;
    mtype* C = (mtype*) malloc(sizeof(mtype)*m*m);
    store_t stypeC = ROWMAJOR;

    randomMat(A, ROWMAJOR, m, m);
    randomMat(B, COLMAJOR, m, m);
    memset(C, 0, m*m * sizeof(mtype));

    //matMulRef_kji(A, stypeA, B, stypeB, C, stypeC, m, m);
    matMulRef(A, stypeA, B, stypeB, C, stypeC, m, m);
}
