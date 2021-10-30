#!/bin/bash
set -e
cd "$(dirname "$0")"
PRE_PWD="$(pwd)"
cd ..
source config
check_build_for_targets '-linux-gnu' || exit 0

PREBUILT_LINUX_HEADER_DIR="$(pwd)/prebuilt-linux-header"
BINUTILS_VERSION=2.24
GCC_VERSION=4.9.4

BUILD_DIR=".build-glibc"
(test -d $BUILD_DIR && rm -rf $BUILD_DIR) || true
mkdir -p $BUILD_DIR && cd $BUILD_DIR

GCC_CROSS_INSTALL_PREFIX="$(pwd)/gcc-cross-install"
GLIBC_STARTFILE_INSTALL_PREFIX="$(pwd)/glibc-startfile-install"
export PATH="$GCC_CROSS_INSTALL_PREFIX/bin:$PATH"

# Prepare binutils
SOURCE_TARBALL=binutils-$BINUTILS_VERSION.tar.gz
mkdir -p "$SOURCE_DIR"
if [ ! -f "$SOURCE_DIR/$SOURCE_TARBALL" ]; then
    curl -sSL "http://mirrors.ustc.edu.cn/gnu/binutils/$SOURCE_TARBALL" -o "$SOURCE_DIR/$SOURCE_TARBALL.tmp"
    mv "$SOURCE_DIR/$SOURCE_TARBALL.tmp" "$SOURCE_DIR/$SOURCE_TARBALL"
fi
mkdir build-binutils && tar_extractor.py "$SOURCE_DIR/$SOURCE_TARBALL" -C build-binutils --strip 1

# Prepare gcc
SOURCE_TARBALL=gcc-$GCC_VERSION.tar.gz
if [ ! -f "$SOURCE_DIR/$SOURCE_TARBALL" ]; then
    curl -sSL "http://mirrors.ustc.edu.cn/gnu/gcc/gcc-$GCC_VERSION/$SOURCE_TARBALL" -o "$SOURCE_DIR/$SOURCE_TARBALL.tmp"
    mv "$SOURCE_DIR/$SOURCE_TARBALL.tmp" "$SOURCE_DIR/$SOURCE_TARBALL"
fi
mkdir build-gcc && tar_extractor.py "$SOURCE_DIR/$SOURCE_TARBALL" -C build-gcc --strip 1

# Prepare glibc
SOURCE_TARBALL=glibc-$GLIBC_VERSION.tar.gz
if [ ! -f "$SOURCE_DIR/$SOURCE_TARBALL" ]; then
    curl -sSL "http://mirrors.ustc.edu.cn/gnu/glibc/$SOURCE_TARBALL" -o "$SOURCE_DIR/$SOURCE_TARBALL.tmp"
    mv "$SOURCE_DIR/$SOURCE_TARBALL.tmp" "$SOURCE_DIR/$SOURCE_TARBALL"
fi
mkdir build-glibc && cd build-glibc
tar_extractor.py "$SOURCE_DIR/$SOURCE_TARBALL" --strip 1
apply_patch glibc-$GLIBC_VERSION
cd ..

for target in "${CROSS_TARGETS[@]}"; do
    if [[ $target != *"-linux-gnu"* ]]; then
        continue
    fi
    CROSS_PREFIX=$target
    CROSS_CFLAGS=""
    GCC_CONFIG_ARGS=""
    KERNEL_ARCH=""
    case $target in
    mips*)
        if [[ $target != "mips64"* ]]; then
            # Use mips32 ISA by default
            CROSS_CFLAGS="$CROSS_CFLAGS -mips32"
        else
            # Use mips64 ISA by default
            GCC_CONFIG_ARGS="$GCC_CONFIG_ARGS --with-arch=mips64 --with-abi=64"
            CROSS_CFLAGS="$CROSS_CFLAGS -mips64 -mabi=64"
        fi
        if [[ $target == *"sf"* ]]; then
            GCC_CONFIG_ARGS="$GCC_CONFIG_ARGS --with-float=soft"
        else
            GCC_CONFIG_ARGS="$GCC_CONFIG_ARGS --with-float=hard"
        fi
        KERNEL_ARCH=mips
        ;;
    aarch64*|arm64*)
        CROSS_PREFIX=aarch64-linux-gnu
        KERNEL_ARCH=arm64
        ;;
    arm*)
        if [[ $target == *"hf" ]]; then
            CROSS_PREFIX=arm-linux-gnueabihf
            GCC_CONFIG_ARGS="$GCC_CONFIG_ARGS --with-float=hard"
        else
            CROSS_PREFIX=arm-linux-gnueabi
            GCC_CONFIG_ARGS="$GCC_CONFIG_ARGS --with-float=soft"
        fi
        if [[ $target == "armv7a"* ]]; then
            # Optimize for arm-v7a
            CROSS_CFLAGS="$CROSS_CFLAGS -march=armv7-a -mfpu=neon"
        fi
        KERNEL_ARCH=arm
        ;;
    i*86*|x86*) 
        KERNEL_ARCH=x86
        ;;
    esac
    # Extract linux header
    mkdir -p "linux-header/$target" && tar_extractor.py "$PREBUILT_LINUX_HEADER_DIR/linux-header-${LINUX_KERNEL_VERSION}_${KERNEL_ARCH}.tar.gz" -C "linux-header/$target"

    # Build bintuils
    mkdir -p build-binutils/build-$target && cd build-binutils/build-$target
    CPPFLAGS="$HOST_CPPFLAGS" CFLAGS="$HOST_CFLAGS -w" CXXFLAGS="$HOST_CXXFLAGS -w" LDFLAGS="$HOST_LDFLAGS" ../configure $CONFIGURE_ARGS --target=$CROSS_PREFIX --prefix="$GCC_CROSS_INSTALL_PREFIX" --disable-werror --with-sysroot=/
    make -j$(cpu_count)
    make install -j$(cpu_count)
    cd ../../

    # Build gcc
    mkdir -p build-gcc/build-$target && cd build-gcc/build-$target
    CPPFLAGS="$HOST_CPPFLAGS" CFLAGS="$HOST_CFLAGS -w" CXXFLAGS="$HOST_CXXFLAGS -w -std=c++11 -O2" LDFLAGS="$HOST_LDFLAGS" \
    CFLAGS_FOR_TARGET="$CROSS_CFLAGS -isystem $GLIBC_STARTFILE_INSTALL_PREFIX/include -O2 -fPIC" \
    ../configure $CONFIGURE_ARGS --target=$CROSS_PREFIX --prefix="$GCC_CROSS_INSTALL_PREFIX" --enable-languages=c \
        --disable-libgomp --disable-libmudflap --disable-libmpx --disable-libquadmath-support --disable-libquadmath --disable-shared $GCC_CONFIG_ARGS
    make -j$(cpu_count) all-gcc
    make -j$(cpu_count) install-gcc
    cd ../../

    # Build glibc - start files
    mkdir -p build-glibc/build-startfile-$target && cd build-glibc/build-startfile-$target
    # Hack unwind and stack protecting requirement
    echo "libc_cv_forced_unwind=yes" > config.cache
    GLIBC_COMMON_CONFIG_ARGS="--prefix=/ --host=$CROSS_PREFIX --disable-debug --disable-sanity-checks --disable-obsolete-rpc --disable-werror --cache-file=./config.cache --with-headers=$(pwd)/../../linux-header/$target/include"
    ../configure $CONFIGURE_ARGS $GLIBC_COMMON_CONFIG_ARGS
    make -j$(cpu_count) install-bootstrap-headers=yes DESTDIR="$GLIBC_STARTFILE_INSTALL_PREFIX" install-headers
    # Create empty stubs.h to fix compile error for libgcc later
    touch "$GLIBC_STARTFILE_INSTALL_PREFIX/include/gnu/stubs.h"

    # Build libgcc
    cd ../../build-gcc/build-$target
    make -j$(cpu_count) all-target-libgcc
    make -j$(cpu_count) install-target-libgcc
    # Create symlink libgcc_eh.a to libgcc.a for glibc later
    ln -sf libgcc.a `$CROSS_PREFIX-gcc -print-libgcc-file-name | sed 's/libgcc/&_eh/'`
    cd ../../

    # Build final glibc
    mkdir -p build-glibc/build-$target && cd build-glibc/build-$target
    # Hack stack protector requirement
    echo "libc_cv_ssp=no" > config.cache
    echo "libc_cv_ssp_strong=no" >> config.cache
    CFLAGS="$CROSS_CFLAGS -fno-stack-protector -O2 -U_FORTIFY_SOURCE" ../configure $CONFIGURE_ARGS $GLIBC_COMMON_CONFIG_ARGS
    make -j$(cpu_count)
    make -j$(cpu_count) DESTDIR="$(pwd)/../../glibc-install/$target" install
    tar cvzf "$PRE_PWD/glibc-${GLIBC_VERSION}_$target.tar.gz" -C "$(pwd)/../../glibc-install/$target" ./include ./lib
    cd ../../
done
