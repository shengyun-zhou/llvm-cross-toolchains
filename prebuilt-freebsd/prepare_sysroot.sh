#!/bin/bash
set -e
cd "$(dirname "$0")"
PRE_PWD="$(pwd)"
cd ..
source config
check_build_for_targets 'freebsd' || exit 0
cd "$PRE_PWD"

for arch in arm64 i386 amd64; do
    mkdir -p .freebsd-sysroot && cd .freebsd-sysroot
    curl -L "http://mirrors.ustc.edu.cn/freebsd/releases/$arch/${FREEBSD_VERSION}-RELEASE/base.txz" -o sysroot.tar.xz
    tar_extractor.py sysroot.tar.xz
    for pic_libfile in "usr/lib/"*_p.a; do
        filename=$(basename "$pic_libfile")
        libfile=${filename%_p.a}.a
        ln -sf $filename "usr/lib/$libfile"
    done
    rm -rf usr/include/c++* || true
    rm -rf usr/include/gcc || true
    rm -rf usr/lib/clang* || true
    rm -rf usr/lib/libcompiler_rt* || true
    rm -rf usr/lib/libc++* || true
    rm -rf usr/lib/libgcc*.a || true
    
    tar cvzf ../freebsd-sysroot-${FREEBSD_VERSION}_$arch.tar.gz ./lib ./usr/include ./usr/lib
    cd .. && rm -rf .freebsd-sysroot
done
