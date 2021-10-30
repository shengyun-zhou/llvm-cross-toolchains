#!/bin/bash
set -e
cd "$(dirname "$0")"
PRE_PWD="$(pwd)"
cd ..
source config
check_build_for_targets 'cygwin' || exit 0
cd "$PRE_PWD"

for target in "${CROSS_TARGETS[@]}"; do
    if [[ $target == *"cygwin"* ]]; then
        CYGWIN_ARCH=x86
        CYGWIN_TARGET=i686-pc-cygwin
        if [[ $target == "x86_64"* ]]; then
            CYGWIN_ARCH=x86_64
            CYGWIN_TARGET=x86_64-pc-cygwin
        fi
        rm -rf .cygwin-sysroot-$CYGWIN_ARCH || true
        mkdir .cygwin-sysroot-$CYGWIN_ARCH && cd .cygwin-sysroot-$CYGWIN_ARCH
        curl -L "https://mirrors.tuna.tsinghua.edu.cn/cygwin/$CYGWIN_ARCH/release/cygwin/cygwin-devel/cygwin-devel-$CYGWIN_VERSION-1.tar.xz" -o cygwin-devel.tar.xz
        tar_extractor.py cygwin-devel.tar.xz
        curl -L "https://mirrors.tuna.tsinghua.edu.cn/cygwin/$CYGWIN_ARCH/release/w32api-headers/w32api-headers-$CYGWIN_W32API_VERSION-1.tar.xz" -o cygwin-w32api-headers.tar.xz
        tar_extractor.py cygwin-w32api-headers.tar.xz
        curl -L "https://mirrors.tuna.tsinghua.edu.cn/cygwin/$CYGWIN_ARCH/release/w32api-runtime/w32api-runtime-$CYGWIN_W32API_VERSION-1.tar.xz" -o cygwin-w32api-runtime.tar.xz
        tar_extractor.py cygwin-w32api-runtime.tar.xz
        curl -L "https://mirrors.tuna.tsinghua.edu.cn/cygwin/$CYGWIN_ARCH/release/gcc/gcc-core/gcc-core-10.2.0-1.tar.xz" -o cygwin-gcc-core.tar.xz
        mkdir gcc && tar_extractor.py cygwin-gcc-core.tar.xz -C gcc
        cp gcc/usr/lib/gcc/$CYGWIN_TARGET/10/crt*.o gcc/usr/lib/gcc/$CYGWIN_TARGET/10/libgcc*.a\
           gcc/usr/lib/gcc/$CYGWIN_TARGET/10/libatomic.a usr/lib
        tar cvzf ../cygwin-sysroot-${CYGWIN_VERSION}_$target.tar.gz -C usr ./include ./lib
        cd ..
        rm -rf .cygwin-sysroot-$CYGWIN_ARCH
    fi
done
