#!/bin/bash
set -e
cd "$(dirname "$0")"
source config
check_build_for_targets 'wasm' || exit 0

SOURCE_TARBALL=wabt-$WABT_VERSION.tar.gz
mkdir -p "$SOURCE_DIR"
if [ ! -f "$SOURCE_DIR/$SOURCE_TARBALL" ]; then
    curl -sSL "https://${GITHUB_MIRROR_DOMAIN:-github.com}/WebAssembly/wabt/archive/refs/tags/$WABT_VERSION.tar.gz" -o "$SOURCE_DIR/$SOURCE_TARBALL.tmp"
    mv "$SOURCE_DIR/$SOURCE_TARBALL.tmp" "$SOURCE_DIR/$SOURCE_TARBALL"
fi
BUILD_DIR=".build-wabt"
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
cmake .. -G Ninja $HOST_CMAKE_FLAGS -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$OUTPUT_DIR" -DBUILD_TESTS=OFF -DBUILD_LIBWASM=OFF -DCMAKE_INSTALL_LIBDIR=lib
cmake --build . --target install/strip
