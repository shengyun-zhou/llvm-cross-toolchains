#!/bin/bash
set -e
cd "$(dirname "$0")"
PRE_PWD="$(pwd)"
cd ..
source config
check_build_for_targets 'msys' || exit 0
cd "$PRE_PWD"

declare -A MSYS_ARCH_MAP
MSYS_ARCH_MAP=(
    ["i686"]="i686-pc-msys"
    ["x86_64"]="x86_64-pc-msys"
)

for MSYS_ARCH in "${!MSYS_ARCH_MAP[@]}"; do
    MSYS_TARGET=${MSYS_ARCH_MAP[$MSYS_ARCH]}
    rm -rf .msys-sysroot-$MSYS_ARCH || true
    mkdir .msys-sysroot-$MSYS_ARCH && cd .msys-sysroot-$MSYS_ARCH
    curl -L "https://mirrors.ustc.edu.cn/msys2/msys/$MSYS_ARCH/msys2-runtime-devel-$MSYS2_VERSION-$MSYS_ARCH.pkg.tar.zst" -o msys2-devel.tar.zst
    tar_extractor.py msys2-devel.tar.zst
    curl -L "https://mirrors.ustc.edu.cn/msys2/msys/$MSYS_ARCH/msys2-w32api-headers-$MSYS2_W32API_VERSION-$MSYS_ARCH.pkg.tar.zst" -o msys2-w32api-headers.tar.zst
    tar_extractor.py msys2-w32api-headers.tar.zst
    curl -L "https://mirrors.ustc.edu.cn/msys2/msys/$MSYS_ARCH/msys2-w32api-runtime-$MSYS2_W32API_VERSION-$MSYS_ARCH.pkg.tar.zst" -o msys2-w32api-runtime.tar.zst
    tar_extractor.py msys2-w32api-runtime.tar.zst
    curl -L "http://mirrors.ustc.edu.cn/msys2/msys/$MSYS_ARCH/gcc-10.2.0-1-$MSYS_ARCH.pkg.tar.zst" -o msys2-gcc.tar.zst
    mkdir gcc && tar_extractor.py msys2-gcc.tar.zst -C gcc
    cp gcc/usr/lib/gcc/$MSYS_TARGET/10.2.0/crt*.o gcc/usr/lib/gcc/$MSYS_TARGET/10.2.0/libgcc*.a\
        gcc/usr/lib/gcc/$MSYS_TARGET/10.2.0/libatomic.a usr/lib
    tar cvzf ../msys2-sysroot-${MSYS2_VERSION}_${MSYS_ARCH}.tar.gz -C usr ./include ./lib
    cd ..
    rm -rf .msys-sysroot-$MSYS_ARCH
done
