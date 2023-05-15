cmake_minimum_required(VERSION 3.22)
project(MyMemtrace)

set(DynamoRIO_DIR "~/.local/opt/DynamoRIO/cmake")
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/lib")
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/bin")

find_package(DynamoRIO)
if (NOT DynamoRIO_FOUND)
  message(FATAL_ERROR "DynamoRIO package required to build")
endif(NOT DynamoRIO_FOUND)

configure_DynamoRIO_global(OFF ON)

function (add_sample_client name source_file_list extension_list)
    add_library(${name} SHARED ${source_file_list})
    configure_DynamoRIO_client(${name})
    foreach (ext ${extension_list})
        use_DynamoRIO_extension(${name} ${ext})
    endforeach (ext)
endfunction()

add_sample_client(mymemtrace_x86 "${CMAKE_SOURCE_DIR}/tracer/mymemtrace.c" 	"drmgr;drreg;drutil;drx")
add_executable(process_memrefs ${CMAKE_SOURCE_DIR}/tracer/process_memrefs.c)
target_link_libraries(process_memrefs sqlite3)

#configure_DynamoRIO_main_headers()

# testing partial tracing
add_executable(matmul ${CMAKE_SOURCE_DIR}/aux/matmul.c)
configure_DynamoRIO_static(matmul)
use_DynamoRIO_drmemtrace(matmul)

add_executable(cachetest ${CMAKE_SOURCE_DIR}/aux/cachetest.c)
set_target_properties(cachetest PROPERTIES COMPILE_FLAGS "-g -O0")

#use_DynamoRIO_static_client(matmul drmemtrace_static)
#link_directories(BEFORE ${DynamoRIO_DIR}/../tools/lib64/release)
#use_DynamoRIO_extension(matmul, drmemtrace_static)
