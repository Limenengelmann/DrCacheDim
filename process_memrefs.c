#include <sqlite3.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdbool.h>

#define die(A) {perror(A); exit(1);}

//#define DB_NAME "data/memrefs.db"

// TODO shared header for mem_ref_t
typedef struct _mem_ref_t {
    bool write;
    void *addr;
    size_t size;
    //app_pc pc;
} mem_ref_t;

typedef size_t ref_t;
//typedef char ref_t;


int main(int argc, char** argv) {

    const char* fname = argv[1];
    const char* dbname = argv[2];

    if (access(fname, F_OK) && mkfifo(fname, 0644)) {
        perror("Could not create pipe."); exit(1);
    }

    printf("Opening '%s'\n", fname);
    int ifile = open(fname, O_RDONLY);
    if (ifile < 0) die("Could not open file");

    sqlite3* DB;
    char* messageError;
    const char *pzTail;
    int status = 0;

    status = sqlite3_open(dbname, &DB);
    if (status) {
        perror(sqlite3_errmsg(DB));
        return (-1);
    }

    sqlite3_exec(DB, "DROP TABLE IF EXISTS MEMREFS;", NULL, 0, &messageError);
    // create table
    const char sql1[] = "CREATE TABLE MEMREFS("
                 "ID INTEGER PRIMARY KEY, "
                 "ADDR INT NOT NULL, "
                 "IS_WRITE INT NOT NULL, "
                 "SIZE INT);";
    status = sqlite3_exec(DB, sql1, NULL, 0, &messageError);
    if (status != SQLITE_OK) 
        //die(messageError);
        fprintf(stderr, messageError);

    const char sql2[] = "INSERT INTO MEMREFS (ADDR, IS_WRITE, SIZE) VALUES (?1, ?2, ?3);";
    sqlite3_stmt *stmt;
    status = sqlite3_prepare_v2(
            DB,
            sql2,                   /* SQL statement, UTF-8 encoded */
            sizeof(sql2),           /* Maximum length of zSql in bytes. */
            &stmt,                  /* OUT: Statement handle */
            &pzTail                 /* OUT: Pointer to unused portion of zSql */
    );
    if (status != SQLITE_OK) 
        die(sqlite3_errmsg(DB));

    printf("Im running 'eeere\n");
    pid_t pid = getpid();
    printf("Process ID: %d\n", pid);
    printf("Parent Process ID: %d\n", getppid());

    sqlite3_exec(DB, "BEGIN TRANSACTION", NULL, 0, &messageError);

    ssize_t r = 0;
    int read_refs;
    size_t count_refs = 0;
    const size_t bsize = 8000;
    mem_ref_t* mem_refs = (mem_ref_t*) calloc(bsize, sizeof(mem_ref_t));

    while( (r = read(ifile, mem_refs, bsize*sizeof(mem_ref_t))) > 0 ) {
        read_refs = r / sizeof(mem_ref_t);
        //printf("Read bytes: %zu, Read_refs: %d, partial ref: %d\n", r, read_refs, r%sizeof(mem_ref_t) > 0);
        // FIXME sometimes addr size and is_write are permuted? Probably some incomplete read
        // Honestly, if possible just do this in lua...
        for (int i=0; i<read_refs; i++) {
        //printf("[%d] Read %zu: %p\n", pid, r, mem_refs[0].addr);
            sqlite3_bind_int64(stmt, 1, (sqlite3_int64) mem_refs[i].addr);
            sqlite3_bind_int(stmt, 2, mem_refs[i].write);
            sqlite3_bind_int64(stmt, 3, mem_refs[i].size);
            status = sqlite3_step(stmt);
            //sqlite3_clear_bindings(stmt);
            sqlite3_reset(stmt);
        }
        count_refs += read_refs;
        //sleep(1);
    }
    printf("\nLoop done. Read %zu memrefs.\nEnding transaction\n", count_refs);
    sqlite3_exec(DB, "END TRANSACTION", NULL, 0, &messageError);
    printf("Bye!\n");
    if (r<0) perror("read failed");
    close(ifile);
    sqlite3_close(DB);
}
