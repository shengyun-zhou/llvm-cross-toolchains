cmake_minimum_required(VERSION 3.13)

project(wamr_ext_libc)

add_library(wamr_dlmalloc OBJECT ${WASI_LIBC_SOURCE}/dlmalloc/src/dlmalloc.c)
add_compile_options(-Werror)
target_compile_definitions(wamr_dlmalloc PRIVATE -DUSE_LOCKS=1 -DUSE_SPIN_LOCKS=0)

set(WASI_LIBC_TOP_HALF_SRC ${WASI_LIBC_SOURCE}/libc-top-half/musl/src)
add_library(wamr_top_half OBJECT
    ${WASI_LIBC_TOP_HALF_SRC}/network/inet_addr.c
    ${WASI_LIBC_TOP_HALF_SRC}/network/inet_legacy.c
    ${WASI_LIBC_TOP_HALF_SRC}/network/inet_ntoa.c
    ${WASI_LIBC_TOP_HALF_SRC}/network/send.c
    ${WASI_LIBC_TOP_HALF_SRC}/network/recv.c
)
target_include_directories(wamr_top_half PRIVATE ${WASI_LIBC_TOP_HALF_SRC}/include)

set(WASI_LIBC_BOTTOM_HALF_SRC ${WASI_LIBC_SOURCE}/libc-bottom-half/source)
set(WASI_LIBC_BOTTOM_HALF_CLOUDLIBC_SRC ${WASI_LIBC_SOURCE}/libc-bottom-half/cloudlibc/src/libc)
add_library(wamr_libc STATIC
    $<TARGET_OBJECTS:wamr_dlmalloc>
    $<TARGET_OBJECTS:wamr_top_half>
    ${WASI_LIBC_BOTTOM_HALF_CLOUDLIBC_SRC}/errno/errno.c
    ${CMAKE_CURRENT_SOURCE_DIR}/src/flock.c
    ${CMAKE_CURRENT_SOURCE_DIR}/src/pthread.c
    ${CMAKE_CURRENT_SOURCE_DIR}/src/socket_api.c
    ${CMAKE_CURRENT_SOURCE_DIR}/src/user_group.c
    ${CMAKE_CURRENT_SOURCE_DIR}/src/utility.c
)

add_custom_command(TARGET wamr_libc POST_BUILD
    COMMAND ${CMAKE_AR} -d ${PREBUILT_WASI_LIBC} dlmalloc.o errno.o recv.o send.o
    COMMAND ${CMAKE_AR} qscL ${PREBUILT_WASI_LIBC} $<TARGET_FILE:wamr_libc>
)
