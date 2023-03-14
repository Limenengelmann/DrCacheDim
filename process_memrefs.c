#include <sqlite3.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdbool.h>

#include "mem_ref.h"

#define die(A) {perror(A); exit(1);}

// TODO shared header for mem_ref_t
typedef struct _mem_ref_t mem_ref_t;

int main(int argc, char** argv) {

    if (argc == 1) {
        die("Not enough arguments\n"
            "Usage: process_memrefs <db-name> [pipe-name]\n");
    }

    const char* fname = argc > 2 ? argv[2] : PIPE_NAME;
    const char* dbname = argv[1]; 

    if (access(fname, F_OK) && mkfifo(fname, 0644))
        die("Could not create pipe.");

    printf("Opening '%s'\n", fname);
    int ifile = open(fname, O_RDONLY);
    if (ifile < 0) 
        die("Could not open file");

    sqlite3* DB;
    char* messageError;
    const char *pzTail;
    int status = 0;

    status = sqlite3_open(dbname, &DB);
    if (status) 
        die(sqlite3_errmsg(DB));

    // dont drop table, append refs instead
    //sqlite3_exec(DB, "DROP TABLE IF EXISTS MEMREFS;", NULL, 0, &messageError);
    // create table
    const char sql1[] = "CREATE TABLE MEMREFS("
                        "ID INTEGER PRIMARY KEY, "
                        "ADDR INT NOT NULL, "
                        "IS_WRITE INT NOT NULL, "
                        "SIZE INT);";
    status = sqlite3_exec(DB, sql1, NULL, 0, &messageError);
    if (status != SQLITE_OK)
        //die(messageError);    // dont die if the table exsists already! Just append
        fprintf(stderr, messageError);

    status = sqlite3_exec(DB, "CREATE TABLE ROW_COUNT "
                              "(ID INTEGER PRIMARY KEY, "
                              "REFS INTEGER DEFAULT 0, "
                              "TIMESTAMP DATETIME DEFAULT CURRENT_TIMESTAMP);"
                              , NULL, 0, &messageError);
    if (status != SQLITE_OK)
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
    size_t readb = 0;
    const size_t bsize = MAX_NUM_MEM_REFS;
    size_t unreadb = MEM_BUF_SIZE;

    char* rbuf = (char*) malloc(unreadb);
    mem_ref_t* mem_refs = (mem_ref_t*) rbuf;

    do {
        do {
            r = read(ifile, rbuf + readb, unreadb);
            readb += r;
            unreadb -= r;
        } while (r > 0 && unreadb > 0);
        if (r < 0) {
            printf("Read failed! Stopping..");
            break;
        }

        read_refs = readb / sizeof(mem_ref_t);
        for (int i=0; i<read_refs; i++) {
            //printf("[%d] Read %zu: %p\n", pid, r, mem_refs[0].addr);
            //XXX sqlite3 has no uint64 type, so some refs might appear negative
            sqlite3_bind_int64(stmt, 1, (sqlite3_int64) mem_refs[i].addr);
            sqlite3_bind_int(stmt, 2, mem_refs[i].write);
            sqlite3_bind_int64(stmt, 3, mem_refs[i].size);
            status = sqlite3_step(stmt);
            sqlite3_reset(stmt);
        }
        count_refs += read_refs;
    } while (r > 0);

    printf("\nLoop done. Read %zu memrefs.\nEnding transaction\n", count_refs);
    sqlite3_exec(DB, "END TRANSACTION", NULL, 0, &messageError);

    char sql4[128];
    // TODO this doesnt insert total properly
    sprintf(sql4, "INSERT INTO ROW_COUNT (REFS) VALUES (%zu);", count_refs);
    status = sqlite3_exec(DB, sql4, NULL, 0, &messageError);
    if (status != SQLITE_OK)
        die(messageError);

    free(rbuf);
    sqlite3_close(DB);
    close(ifile);

    printf("Bye!\n");
}
