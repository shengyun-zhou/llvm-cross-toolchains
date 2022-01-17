#!/bin/bash
set -e
cd "$(dirname "$0")"
source config
check_build_for_targets 'wasm' || exit 0

# Build binaryen
SOURCE_TARBALL=binaryen-$BINARYEN_VERSION.tar.gz
mkdir -p "$SOURCE_DIR"
if [ ! -f "$SOURCE_DIR/$SOURCE_TARBALL" ]; then
    curl -sSL "https://${GITHUB_MIRROR_DOMAIN:-github.com}/WebAssembly/binaryen/archive/refs/tags/version_$BINARYEN_VERSION.tar.gz" -o "$SOURCE_DIR/$SOURCE_TARBALL.tmp"
    mv "$SOURCE_DIR/$SOURCE_TARBALL.tmp" "$SOURCE_DIR/$SOURCE_TARBALL"
fi
BUILD_DIR=".build-binaryen"
(test -d $BUILD_DIR && rm -rf $BUILD_DIR) || true
mkdir -p $BUILD_DIR
tar_extractor.py "$SOURCE_DIR/$SOURCE_TARBALL" -C $BUILD_DIR --strip 1
cd $BUILD_DIR

export CC="$HOST_CC"
export CXX="$HOST_CXX"
export CFLAGS="$HOST_CFLAGS"
export CXXFLAGS="$HOST_CXXFLAGS"
export LDFLAGS="$HOST_LDFLAGS"

mkdir build && cd build
BINARYEN_CMAKE_FLAGS=""
if [[ -n "$BINARYEN_STATIC_BUILD" ]]; then
    BINARYEN_CMAKE_FLAGS="$BINARYEN_CMAKE_FLAGS -DBUILD_STATIC_LIB=ON"
fi
cmake .. -G Ninja $HOST_CMAKE_FLAGS -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$OUTPUT_DIR" -DENABLE_WERROR=OFF -DCMAKE_INSTALL_LIBDIR=lib $BINARYEN_CMAKE_FLAGS
cmake --build . --target install/strip
