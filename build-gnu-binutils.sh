#!/bin/bash
set -e
cd "$(dirname "$0")"
source config

BUILD_DIR=".build-gnu-binutils"

(test -d $BUILD_DIR && rm -rf $BUILD_DIR) || true
mkdir -p $BUILD_DIR && cd $BUILD_DIR
SOURCE_TARBALL=binutils-$GNU_BINUTILS_VERSION.tar.xz  
mkdir -p "$SOURCE_DIR"
if [ ! -f "$SOURCE_DIR/$SOURCE_TARBALL" ]; then
    curl -sSL "http://mirrors.ustc.edu.cn/gnu/binutils/binutils-$GNU_BINUTILS_VERSION.tar.xz" -o "$SOURCE_DIR/$SOURCE_TARBALL.tmp"
    mv "$SOURCE_DIR/$SOURCE_TARBALL.tmp" "$SOURCE_DIR/$SOURCE_TARBALL"
fi
tar_extractor.py "$SOURCE_DIR/$SOURCE_TARBALL" --strip 1

# LDFLAGS may not work for libtool, append it to CC
export CPP="$HOST_CPP"
export CC="${HOST_CC:-cc} $HOST_LDFLAGS"
export CXX="${HOST_CXX:-c++} $HOST_LDFLAGS"
export CPPFLAGS="$HOST_CPPFLAGS"
export CFLAGS="$HOST_CFLAGS"
export CXXFLAGS="$HOST_CXXFLAGS"
export LDFLAGS="$HOST_LDFLAGS"

for target in "${CROSS_TARGETS[@]}"; do
    if [[ $target == "riscv"*"-linux-"* || $target == *"cygwin"* || $target == *"msys"* ]]; then
        mkdir build-$target && cd build-$target
        binutils_target=$target
        if [[ $target == *"msys"* ]]; then
            binutils_target=${target/msys/cygwin}
        fi
        ../configure $HOST_CONFIGURE_ARGS $CONFIGURE_ARGS --target=$binutils_target --prefix="$(pwd)/binutils-install" --disable-werror --with-sysroot=/
        make -j$(cpu_count)
        make install
        rm -f binutils-install/bin/$binutils_target-as${CROSS_EXEC_SUFFIX} || true
        for binfile in binutils-install/bin/*; do
            "${HOST_STRIP:-strip}" "$binfile"
            binfile_basename="$(basename "$binfile")"
            binfile_basename=${binfile_basename/$binutils_target/$target}
            rm -f "$OUTPUT_DIR/bin/$binfile_basename" || true
            cp "$binfile" "$OUTPUT_DIR/bin/$binfile_basename"
        done
        cd ..
    fi
done

