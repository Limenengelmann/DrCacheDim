#include "matrix.h"

// checkerboard size (global scope)
int g_checkerb_n = 0;

void randomMat(mtype* A, store_t stypeA, int m, int n){
    for (int i=0; i<m; i++) {
        for (int j=0; j<n; j++) {
            A[INDEX(i, j, m, n, stypeA)] = (mtype) rand() / (mtype)(RAND_MAX);
        }
    }
}

void unitMat(mtype* A, store_t stypeA, mtype d, int m, int n){
    for (int i=0; i<m; i++) {
        for (int j=0; j<n; j++) {
            if (i==j) {
                A[INDEX(i, j, m, n, stypeA)] = d;
            } else {
                A[INDEX(i, j, m, n, stypeA)] = 0;
            }
        }
    }
}

void phoneMat(mtype* A, store_t stypeA, int m, int n){
    for (int i=0; i<m; i++) {
        for (int j=0; j<n; j++) {
            A[INDEX(i, j, m, n, stypeA)] = i*n + j;
        }
    }
}

void copyMat(mtype* A, store_t stypeA, mtype* A_cpy, store_t stypeA_new, int n){
    for (int i=0; i<n; i++) {
        for (int j=0; j<n; j++) {
            A_cpy[INDEX(i, j, n, n, stypeA_new)] = A[INDEX(i, j, n, n, stypeA)];
        }
    }
}

double matrixError(mtype* A, store_t stypeA, mtype* B, store_t stypeB, int m, int n){
    double err = 0;
    double tmp;
    for (int i=0; i<m; i++) {
        for (int j=0; j<n; j++) {
            tmp = fabs(A[INDEX(i, j, m, n, stypeA)] - B[INDEX(i, j, m, n, stypeB)]);
            err = tmp > err ? tmp : err;
        }
    }
    return err;
}

// reference algorithm
void matMulRef(mtype* A, store_t stypeA, mtype* B, store_t stypeB, mtype* C, store_t stypeC, int m, int n){
    // Would probably be more efficient to transform the matrices into one fixed format first, multiply, and switch them back, but should only be used for small matrix sizes anyway.

    mtype tmp;
    #pragma OMP parallel for
    for (int i=0; i<m; i++) {
        for (int j=0; j<m; j++) {
            for (int k=0; k<n; k++) {
                // BUG WAS flipped m, n in B[INDEX(k, j, n, m, stypeB)] 
                C[INDEX(i, j, m, m, stypeC)] += A[INDEX(i, k, m, n, stypeA)] * B[INDEX(k, j, n, m, stypeB)];
            }
        }
    }
}

void matMulRef_kji(mtype* A, store_t stypeA, mtype* B, store_t stypeB, mtype* C, store_t stypeC, int m, int n){
    // Would probably be more efficient to transform the matrices into one fixed format first, multiply, and switch them back, but should only be used for small matrix sizes anyway.

    mtype tmp;
    #pragma OMP parallel for
    for (int k=0; k<n; k++) {
        for (int j=0; j<m; j++) {
            for (int i=0; i<m; i++) {
                C[INDEX(i, j, m, m, stypeC)] += A[INDEX(i, k, m, n, stypeA)] * B[INDEX(k, j, n, m, stypeB)];
            }
        }
    }
}

void matMulRef_kij(mtype* A, store_t stypeA, mtype* B, store_t stypeB, mtype* C, store_t stypeC, int m, int n){
    // Would probably be more efficient to transform the matrices into one fixed format first, multiply, and switch them back, but should only be used for small matrix sizes anyway.

    mtype tmp;
    #pragma OMP parallel for
    for (int k=0; k<n; k++) {
        for (int i=0; i<m; i++) {
            for (int j=0; j<m; j++) {
                C[INDEX(i, j, m, m, stypeC)] += A[INDEX(i, k, m, n, stypeA)] * B[INDEX(k, j, n, m, stypeB)];
            }
        }
    }
}

void matMulRef_ikj(mtype* A, store_t stypeA, mtype* B, store_t stypeB, mtype* C, store_t stypeC, int m, int n){
    // Would probably be more efficient to transform the matrices into one fixed format first, multiply, and switch them back, but should only be used for small matrix sizes anyway.

    mtype tmp;
    #pragma OMP parallel for
    for (int i=0; i<m; i++) {
        for (int k=0; k<n; k++) {
            for (int j=0; j<m; j++) {
                C[INDEX(i, j, m, m, stypeC)] += A[INDEX(i, k, m, n, stypeA)] * B[INDEX(k, j, n, m, stypeB)];
            }
        }
    }
}

void matMulRef_jki(mtype* A, store_t stypeA, mtype* B, store_t stypeB, mtype* C, store_t stypeC, int m, int n){
    // Would probably be more efficient to transform the matrices into one fixed format first, multiply, and switch them back, but should only be used for small matrix sizes anyway.

    mtype tmp;
    #pragma OMP parallel for
    for (int j=0; j<m; j++) {
        for (int k=0; k<n; k++) {
            for (int i=0; i<m; i++) {
                C[INDEX(i, j, m, m, stypeC)] += A[INDEX(i, k, m, n, stypeA)] * B[INDEX(k, j, n, m, stypeB)];
            }
        }
    }
}

void matMulRef_jik(mtype* A, store_t stypeA, mtype* B, store_t stypeB, mtype* C, store_t stypeC, int m, int n){
    // Would probably be more efficient to transform the matrices into one fixed format first, multiply, and switch them back, but should only be used for small matrix sizes anyway.

    mtype tmp;
    #pragma OMP parallel for
    for (int j=0; j<m; j++) {
        for (int i=0; i<m; i++) {
            for (int k=0; k<n; k++) {
                C[INDEX(i, j, m, m, stypeC)] += A[INDEX(i, k, m, n, stypeA)] * B[INDEX(k, j, n, m, stypeB)];
            }
        }
    }
}

// moved MIN(.,.) macro to matrix.h
void matMulChunk(mtype* mat_a, mtype* mat_b, mtype* mat_c, int m, int n) {
    const int blockSize = MIN(MIN(m, n), 16);

    int i, j, jj, k, kk;

    memset(mat_c, 0, m*m * sizeof(mtype));

    for (jj = 0; jj < m; jj = jj + blockSize) {
        for (kk = 0; kk < n; kk = kk + blockSize) {
            for (i = 0; i < m; i = i + 1) {
                for (j = jj; j < MIN(jj+blockSize, m); j = j + 1) {
                    for (k = kk; k < MIN(kk+blockSize, n); k = k + 1) {
                        mat_c[i*m+ j] += mat_a[i*n + k] * mat_b[k + j*n];
                        //mat_c[INDEX(i, j, m, m, ROWMAJOR)] += mat_a[INDEX(i, k, m, n, ROWMAJOR)] * mat_b[INDEX(k, j, n, m, COLMAJOR)];
                    }
    } } } }
}

void printMat(mtype* A, store_t stypeA, int m, int n){
    char stype[3][32] = {"rowmajor", "colmajor", "checkerboard"};
    printf("[%dx%d], storage type: %s\n", m, n, stype[stypeA]);
    for (int i=0; i<m; i++) {
        for (int j=0; j<n; j++) {
            printf("%6.2f ", A[INDEX(i, j, m, n, stypeA)]);
        }
        printf("\n");
    }
    printf("\n");
}

int read_matrix(FILE* file, mtype *A, store_t stypeA, int n){
    for (int i=0; i < n; i++) {
        for (int j=0; j < n; j++) {
            if (EOF == fscanf(file, "%lf", A+INDEX(i, j, n, n, stypeA))) {
                perror("Couldn't read elements from input file to matrix A");
                return -1;
            }
        }
    }
    return 0;
}

int read_input(const char *file_name, mtype **matrixA, store_t stypeA, mtype **matrixB, store_t stypeB, mtype **matrixC) {
    FILE *file;

    if (NULL == (file = fopen(file_name, "r"))) {
        perror("Couldn't open input file");
        return -1;
    }

    // Read the first int in the file (tells the size of each matrix)
    int mSize;
    if (EOF == fscanf(file, "%d", &mSize)) {
        perror("Couldn't read element count from input file");
        return -1;
    }

    int mSize2 = mSize * mSize; 
    // Allocate space for both matricies
    if (NULL == (*matrixA = (mtype*) malloc(mSize2 * sizeof(mtype)))) {
        perror("Couldn't allocate memory for matrix A");
        return -1;
    }
    //printf("Init'd A\n");

    if (NULL == (*matrixB = (mtype*) malloc(mSize2 * sizeof(mtype)))) {
        perror("Couldn't allocate memory for matrix B");
        return -1;
    }
    //printf("Init'd B\n");

    if (NULL == (*matrixC = (mtype*) malloc(mSize2 * sizeof(mtype)))) {
        perror("Couldn't allocate memory for matrix C");
        return -1;
    }
    //printf("Init'd C\n");

    // Load matrix A
    read_matrix(file, *matrixA, stypeA, mSize);

    // Load Matrix B
    read_matrix(file, *matrixB, stypeB, mSize);
    //printf("Loaded B\n");

    // Close the file
    if (0 != fclose(file)){
        perror("Warning: couldn't close input file");
    }
    //printf("Closed file\n");

    return mSize;
}

// PRODUCE_OUTPUT_FILE flag moved to matmul.h
int write_output(const char *file_name, mtype *C, store_t stypeC, int mSize) {
    FILE *file;
    if (NULL == (file = fopen(file_name, "w"))) {
        perror("Couldn't open output file");
        return -1;
    }

    for (int i=0; i < mSize; i++) {
        for (int j=0; j < mSize; j++) {
            if (0 > fprintf(file, "%.6f ", C[INDEX(i, j, mSize, mSize, stypeC)])) {
                perror("Couldn't read elements from input file to matrix A");
                return -1;
            }
        }
    }

    if (0 > fprintf(file, "\n")) {
        perror("Couldn't write to output file");
    }
    if (0 != fclose(file)) {
        perror("Warning: couldn't close output file");
    }
    return 0;
}
