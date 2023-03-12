cmake_minimum_required(VERSION 3.16)
project(MyMemtrace)

set(DynamoRIO_DIR "/opt/DynamoRIO/DynamoRIO-Linux-9.90.19403/cmake")

# built custom instrumentation client to record+count instructions
find_package(DynamoRIO)
#configure_DynamoRIO_global(OFF ON)

#set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/lib")

function (add_sample_client name source_file_list extension_list)
    add_library(${name} SHARED ${source_file_list})
    configure_DynamoRIO_client(${name})
    foreach (ext ${extension_list})
        use_DynamoRIO_extension(${name} ${ext})
    endforeach (ext)
endfunction()
if (NOT DynamoRIO_FOUND)
    message(FATAL_ERROR "Package DynamoRIO not found!")
endif()

add_sample_client(mymemtrace_x86 "${CMAKE_SOURCE_DIR}/mymemtrace.c" 	"drmgr;drreg;drutil;drx")
# original
#add_sample_client(memtrace_x86_binary "memtrace_x86.c;utils.c" "drcontainers;drmgr;drreg;drutil;drx")

add_executable(process_memrefs process_memrefs.c)
target_link_libraries(process_memrefs sqlite3)
