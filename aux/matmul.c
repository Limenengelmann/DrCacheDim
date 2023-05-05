#include "dr_api.h"
#include <assert.h>

int main(int argc, const char *argv[]) {
    dr_app_setup();
    assert(!dr_app_running_under_dynamorio());
    printf("Running!\n");
    dr_app_stop_and_cleanup();
}
