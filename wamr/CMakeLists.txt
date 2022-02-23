cmake_minimum_required(VERSION 3.13)

project(wamr_ext_libc)

add_library(wamr_dlmalloc OBJECT ${WASI_LIBC_SOURCE}/dlmalloc/src/dlmalloc.c)
add_compile_options(-Werror -Wno-switch)
target_compile_definitions(wamr_dlmalloc PRIVATE -DUSE_LOCKS=1 -DUSE_SPIN_LOCKS=0)

set(WASI_LIBC_TOP_HALF_SRC ${WASI_LIBC_SOURCE}/libc-top-half/musl/src)
add_library(wamr_top_half OBJECT
    ${WASI_LIBC_TOP_HALF_SRC}/network/inet_addr.c
    ${WASI_LIBC_TOP_HALF_SRC}/network/inet_legacy.c
    ${WASI_LIBC_TOP_HALF_SRC}/network/inet_ntoa.c
    ${WASI_LIBC_TOP_HALF_SRC}/network/send.c
    ${WASI_LIBC_TOP_HALF_SRC}/network/recv.c
    ${WASI_LIBC_TOP_HALF_SRC}/network/dn_expand.c
    ${WASI_LIBC_TOP_HALF_SRC}/network/dns_parse.c
    ${WASI_LIBC_TOP_HALF_SRC}/network/freeaddrinfo.c
    ${WASI_LIBC_TOP_HALF_SRC}/network/gai_strerror.c
    ${WASI_LIBC_TOP_HALF_SRC}/network/getaddrinfo.c
    ${WASI_LIBC_TOP_HALF_SRC}/network/gethostbyaddr_r.c
    ${WASI_LIBC_TOP_HALF_SRC}/network/gethostbyaddr.c
    ${WASI_LIBC_TOP_HALF_SRC}/network/gethostbyname_r.c
    ${WASI_LIBC_TOP_HALF_SRC}/network/gethostbyname.c
    ${WASI_LIBC_TOP_HALF_SRC}/network/gethostbyname2_r.c
    ${WASI_LIBC_TOP_HALF_SRC}/network/gethostbyname2.c
    ${WASI_LIBC_TOP_HALF_SRC}/network/getnameinfo.c
    ${WASI_LIBC_TOP_HALF_SRC}/network/getservbyname_r.c
    ${WASI_LIBC_TOP_HALF_SRC}/network/getservbyname.c
    ${WASI_LIBC_TOP_HALF_SRC}/network/getservbyport_r.c
    ${WASI_LIBC_TOP_HALF_SRC}/network/getservbyport.c
    ${WASI_LIBC_TOP_HALF_SRC}/network/lookup_ipliteral.c
    ${WASI_LIBC_TOP_HALF_SRC}/network/lookup_name.c
    ${WASI_LIBC_TOP_HALF_SRC}/network/lookup_serv.c
    ${WASI_LIBC_TOP_HALF_SRC}/network/res_init.c
    ${WASI_LIBC_TOP_HALF_SRC}/network/res_mkquery.c
    ${WASI_LIBC_TOP_HALF_SRC}/network/res_msend.c
    ${WASI_LIBC_TOP_HALF_SRC}/network/res_query.c
    ${WASI_LIBC_TOP_HALF_SRC}/network/res_querydomain.c
    ${WASI_LIBC_TOP_HALF_SRC}/network/res_send.c
    ${WASI_LIBC_TOP_HALF_SRC}/network/res_state.c
    ${WASI_LIBC_TOP_HALF_SRC}/network/resolvconf.c
    ${WASI_LIBC_TOP_HALF_SRC}/network/herror.c
    ${WASI_LIBC_TOP_HALF_SRC}/network/hstrerror.c
)
target_include_directories(wamr_top_half PRIVATE ${WASI_LIBC_TOP_HALF_SRC}/include ${WASI_LIBC_TOP_HALF_SRC}/internal)

set(WASI_LIBC_BOTTOM_HALF_SRC ${WASI_LIBC_SOURCE}/libc-bottom-half/source)
set(WASI_LIBC_BOTTOM_HALF_CLOUDLIBC_SRC ${WASI_LIBC_SOURCE}/libc-bottom-half/cloudlibc/src/libc)
add_library(wamr_libc STATIC
    $<TARGET_OBJECTS:wamr_dlmalloc>
    $<TARGET_OBJECTS:wamr_top_half>
    ${CMAKE_CURRENT_SOURCE_DIR}/src/filesystem.c
    ${CMAKE_CURRENT_SOURCE_DIR}/src/pthread.c
    ${CMAKE_CURRENT_SOURCE_DIR}/src/socket_api.c
    ${CMAKE_CURRENT_SOURCE_DIR}/src/user_group.c
    ${CMAKE_CURRENT_SOURCE_DIR}/src/utility.c
    ${CMAKE_CURRENT_SOURCE_DIR}/src/sysconf.c
    ${CMAKE_CURRENT_SOURCE_DIR}/src/fcntl.c 
)

add_custom_command(TARGET wamr_libc POST_BUILD
    COMMAND ${CMAKE_AR} -d ${PREBUILT_WASI_LIBC} dlmalloc.o recv.o send.o getsockopt.o sysconf.o fcntl.o
    COMMAND ${CMAKE_AR} qscL ${PREBUILT_WASI_LIBC} $<TARGET_FILE:wamr_libc>
)
