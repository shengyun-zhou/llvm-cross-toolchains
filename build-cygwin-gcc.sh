#!/bin/bash
set -e
cd "$(dirname "$0")"
source config
check_build_for_targets 'cygwin' || exit 0

GCC_VERSION=11.2.0

BUILD_DIR=".build-cygwin-gcc"
(test -d $BUILD_DIR && rm -rf $BUILD_DIR) || true
mkdir -p $BUILD_DIR && cd $BUILD_DIR

GCC_CROSS_INSTALL_PREFIX="$(pwd)/gcc-cross-install"
SOURCE_TARBALL=gcc-$GCC_VERSION.tar.gz
if [ ! -f "$SOURCE_DIR/$SOURCE_TARBALL" ]; then
    curl -sSL "http://mirrors.ustc.edu.cn/gnu/gcc/gcc-$GCC_VERSION/$SOURCE_TARBALL" -o "$SOURCE_DIR/$SOURCE_TARBALL.tmp"
    mv "$SOURCE_DIR/$SOURCE_TARBALL.tmp" "$SOURCE_DIR/$SOURCE_TARBALL"
fi
mkdir build-gcc && tar_extractor.py "$SOURCE_DIR/$SOURCE_TARBALL" -C build-gcc --strip 1
cd build-gcc

# LDFLAGS may not work for libtool, append it to CC
export CPP="$HOST_CPP"
export CC="${HOST_CC:-cc} -w $HOST_LDFLAGS"
export CXX="${HOST_CXX:-c++} -w $HOST_LDFLAGS"
export CPPFLAGS="$HOST_CPPFLAGS"
export CFLAGS="$HOST_CFLAGS"
export CXXFLAGS="$HOST_CXXFLAGS"
unset LDFLAGS

for target in "${CROSS_TARGETS[@]}"; do
    if [[ $target == *"cygwin"* ]]; then
        mkdir build-$target && cd build-$target
        ../configure $HOST_CONFIGURE_ARGS $CONFIGURE_ARGS --target=$target --prefix="$GCC_CROSS_INSTALL_PREFIX" --enable-languages=c \
            --disable-libgomp --disable-libmudflap --disable-libmpx --disable-libquadmath-support --disable-libquadmath --disable-shared \
            --enable-linker-build-id --disable-libstdcxx-pch
        make -j$(cpu_count) all-gcc
        make -j$(cpu_count) install-gcc

        GCC_BIN_FILE="$GCC_CROSS_INSTALL_PREFIX/bin/$target-gcc${CROSS_EXEC_SUFFIX}"
        "${HOST_STRIP:-strip}" "$GCC_BIN_FILE"
        if [[ -n "$HOST_RPATH" ]]; then
            # Fix rpath
            if [[ $CROSS_HOST != "Darwin" ]]; then
                patchelf --set-rpath "$HOST_RPATH" "$GCC_BIN_FILE"
            fi
        fi
        cp "$GCC_BIN_FILE" "$OUTPUT_DIR/bin/$target-gcc-ld${CROSS_EXEC_SUFFIX}"
        cd ..
    fi
done
