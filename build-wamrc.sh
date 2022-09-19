#!/bin/bash
set -e
cd "$(dirname "$0")"
source config
check_build_for_targets '-wamr' || exit 0

SOURCE_TARBALL=WAMR-$WAMR_VERSION.tar.gz
mkdir -p "$SOURCE_DIR"
if [ ! -f "$SOURCE_DIR/$SOURCE_TARBALL" ]; then
    curl -sSL "https://${GITHUB_MIRROR_DOMAIN:-github.com}/bytecodealliance/wasm-micro-runtime/archive/refs/tags/WAMR-$WAMR_VERSION.tar.gz" -o "$SOURCE_DIR/$SOURCE_TARBALL.tmp"
    mv "$SOURCE_DIR/$SOURCE_TARBALL.tmp" "$SOURCE_DIR/$SOURCE_TARBALL"
fi
BUILD_DIR=".build-wamrc"
(test -d $BUILD_DIR && rm -rf $BUILD_DIR) || true
mkdir -p $BUILD_DIR
tar_extractor.py "$SOURCE_DIR/$SOURCE_TARBALL" -C $BUILD_DIR --strip 1
cd $BUILD_DIR
apply_patch wamr-$WAMR_VERSION

export CC="$HOST_CC"
export CXX="$HOST_CXX"
export CFLAGS="$HOST_CFLAGS"
export CXXFLAGS="$HOST_CXXFLAGS"
export LDFLAGS="$HOST_LDFLAGS"

cd wamr-compiler && mkdir build && cd build
WAMR_BUILD_TARGET=X86_64
if [[ "$CROSS_PREFIX" == "aarch64"* || "$CROSS_PREFIX" == "arm64"* ]]; then
    WAMR_BUILD_TARGET=AARCH64
fi
cmake .. -G Ninja $HOST_CMAKE_FLAGS -DCMAKE_BUILD_TYPE=Release -DLLVM_DIR="$OUTPUT_DIR/lib/cmake/llvm" -DWAMR_BUILD_WITH_CUSTOM_LLVM=1 \
    -DWAMR_BUILD_LIBC_UVWASI=0 -DWAMR_BUILD_INVOKE_NATIVE_GENERAL=1 -DWAMR_DISABLE_HW_BOUND_CHECK=1 -DWAMR_BUILD_TARGET=${WAMR_BUILD_TARGET}
cmake --build . --target wamrc
"${HOST_STRIP:-strip}" "wamrc${CROSS_EXEC_SUFFIX}" && cp "wamrc${CROSS_EXEC_SUFFIX}" "$OUTPUT_DIR/bin"
