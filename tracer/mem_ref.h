#pragma once

/* Each mem_ref_t includes the type of reference (read or write),
 * the address referenced, and the size of the reference.
 */

typedef struct _mem_ref_t {
    bool write;
    void *addr;
    size_t size;
    //app_pc pc;
} mem_ref_t;

/* Max number of mem_ref a buffer can have */
#define MAX_NUM_MEM_REFS 8192

/* The size of memory buffer for holding mem_refs. When it fills up,
 * we dump data from the buffer to the file.
 */
#define MEM_BUF_SIZE (sizeof(mem_ref_t) * MAX_NUM_MEM_REFS)

#define PIPE_NAME "/tmp/my_drio_pipe"
