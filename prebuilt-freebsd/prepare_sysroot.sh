#!/bin/bash
set -e
cd "$(dirname "$0")"
PRE_PWD="$(pwd)"
cd ..
source config
check_build_for_targets 'freebsd' || exit 0
cd "$PRE_PWD"

for arch in arm64 i386 amd64; do
    mkdir .freebsd-sysroot && cd .freebsd-sysroot
    curl -L "http://mirrors.ustc.edu.cn/freebsd/releases/$arch/${FREEBSD_VERSION}-RELEASE/base.txz" -o sysroot.tar.xz
    tar_extractor.py sysroot.tar.xz
    tar cvzf ../freebsd-sysroot-${FREEBSD_VERSION}_$arch.tar.gz ./lib ./usr/include ./usr/lib \
        --exclude=./usr/include/c++* --exclude=./usr/include/gcc --exclude=./usr/lib/clang --exclude=./usr/lib/libcompiler_rt* \
        --exclude=./usr/lib/libc++* --exclude=./usr/lib/libgcc*.a
    cd .. && rm -rf .freebsd-sysroot
done
