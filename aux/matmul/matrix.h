#ifndef MATRIX_H
#define MATRIX_H

#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <omp.h>
#include <math.h>
#include <string.h>

// dunno if we have to use float or double
// both need to be changed to switch to float!
typedef double mtype;
#define MPI_MTYPE MPI_DOUBLE

// storage layouts
typedef enum store_t {ROWMAJOR, COLMAJOR, CHECKERBOARD} store_t;

// checkerboard size (global scope)
// Didn't want a struct just for storage types and this also guarantees that the
// checkerboard size is consistent across every matrix
extern int g_checkerb_n;

// macro for slow but safe element access. Evaluates to the elements relative position in memory.
// usage: mathmatical indices A(i, j) translates to A[INDEX(i, j, n, stype)]
// supports arbitrary size for rowmajor or colmajor, 
// but only quadratic matrices with quadratic blocking for checkerboard layout
#define INDEX(i, j, m, n, store_t) ( \
    store_t == ROWMAJOR ? (i)*(n)+(j) : \
    store_t == COLMAJOR ? (i) + (j)*(m) : \
    store_t == CHECKERBOARD ? \
        (((i)/g_checkerb_n)*(n/g_checkerb_n) + (j)/g_checkerb_n)*g_checkerb_n*g_checkerb_n \
        + (i)%g_checkerb_n * g_checkerb_n + (j)%g_checkerb_n \
        : -printf("INDEX: UNKNOWN STORAGE ORDER %d\n", store_t) \
)

#define MIN(x, y) ((x) <= (y) ? (x) : (y))

// reference algorithm
// A is mxn
// B is nxm
// C is mxm
void matMulRef(mtype* A, store_t stypeA, mtype* B, store_t stypeB, mtype* C, store_t stypeC, int m, int n);
void matMulRef_kji(mtype* A, store_t stypeA, mtype* B, store_t stypeB, mtype* C, store_t stypeC, int m, int n);

// generate an n-by-n rowMajor matrix with random elements in [0,1). Mayas input files also seem to just be random matrices
void randomMat(mtype* A, store_t stypeA, int m, int n);

// diagonal n-by-n matrix with diagonal value d
void unitMat(mtype* A, store_t stypeA, mtype d, int m, int n);

// n-by-n matrix with rowise increasing value (1, 2,...,n; n+1, n+2,...)
void phoneMat(mtype* A, store_t stypeA, int m, int n);

// copy n-by-n matrices and/or change storage layout of matrix A from OldP to NewP in A_new
// A_new will have storage type stypeA_new and the elements of A
void copyMat(mtype* A, store_t stypeA, mtype* A_new, store_t stypeA_new, int n);

// maximum of the absolut elementwise difference of n-by-n matrices A and B
double matrixError(mtype* A, store_t stypeA, mtype* B, store_t stypeB, int m, int n);

// print a m-by-n matrix and its storage type
// printing a checkerboard matrix assumes m=n
void printMat(mtype* A, store_t stypeA, int m, int n);

// Main function that does the blocked matrix multiplication
// m, n are the size of A, e.g.
// A is assumed to be rowmajor of size (m x n)
// B is assumed to be colmajor of size (n x m)
// C will be rowmajor of size (m x m)
void matMulChunk(mtype* mat_a, mtype* mat_b, mtype* mat_c, int m, int n);

// Read both matrices from file
int read_input(const char *file_name, mtype **matrixA, store_t stypeA, mtype **matrixB, store_t stypeB, mtype **matrixC);

// Read a single matrix from a file
int read_matrix(FILE* file, mtype *A, store_t stypeA, int n);

// Write to output file
int write_output(const char *file_name, mtype *C, store_t stypeC, int mSize);
#endif
