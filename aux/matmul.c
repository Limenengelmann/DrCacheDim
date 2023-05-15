#include "dr_api.h"
#include <assert.h>

int main(int argc, const char *argv[]) {

        /* We also test -rstats_to_stderr */
    if (setenv("DYNAMORIO_OPTIONS",
                   "-stderr_mask 0xc ", 1))
                   //"-stderr_mask 0xc -rstats_to_stderr ", 1))
        fprintf(stderr, "Failed to set env var!\n");
    //               "-client_lib drcachesim';;-offline'", 1))
    //if (setenv("DYNAMORIO_OPTIONS",
    //               "-stderr_mask 0xc -rstats_to_stderr "
    //               "-client_lib drcachesim", 1))

    printf("Starting!\n");
    assert(!dr_app_running_under_dynamorio());
    dr_app_setup_and_start();
    assert(dr_app_running_under_dynamorio());
    printf("Running!\n");
    dr_app_stop_and_cleanup();
    printf("Quitting!\n");
}

/* Test if the drmemtrace_client_main() in drmemtrace will be called. */
//DR_EXPORT WEAK void
DR_EXPORT WEAK void
drmemtrace_client_main(client_id_t id, int argc, const char *argv[]);
//
///* This dr_client_main should be called instead of the one in tracer.cpp */
DR_EXPORT void
dr_client_main(client_id_t id, int argc, const char *argv[])
{
    fprintf(stderr, "app dr_client_main\n");
    drmemtrace_client_main(id, argc, argv);
}
