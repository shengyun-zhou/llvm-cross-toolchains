#!/bin/bash
set -e
cd "$(dirname "$0")"
source config
check_build_for_targets '-wamr' || exit 0

export PATH="$OUTPUT_DIR/bin:$PATH"
SOURCE_TARBALL=wamr-ext-libs-${WAMR_EXT_LIBS_COMMIT_ID:0:8}.tar.gz
mkdir -p "$SOURCE_DIR"
if [ ! -f "$SOURCE_DIR/$SOURCE_TARBALL" ]; then
    curl -sSL "https://${GITHUB_MIRROR_DOMAIN:-github.com}/shengyun-zhou/wamr-wasm-libs/archive/$WAMR_EXT_LIBS_COMMIT_ID.tar.gz" -o "$SOURCE_DIR/$SOURCE_TARBALL.tmp"
    mv "$SOURCE_DIR/$SOURCE_TARBALL.tmp" "$SOURCE_DIR/$SOURCE_TARBALL"
fi
BUILD_DIR=".build-wamr-ext-libc"
(test -d $BUILD_DIR && rm -rf $BUILD_DIR) || true
mkdir -p $BUILD_DIR
tar_extractor.py "$SOURCE_DIR/$SOURCE_TARBALL" -C $BUILD_DIR --strip 1
cd $BUILD_DIR

for target in "${CROSS_TARGETS[@]}"; do
    if [[ $target != *"-wamr"*"-wasi"* ]]; then
        continue
    fi
    rm -rf sysroot || true
    CROSS_PREFIX=$target ./build-init-wasi-libc.sh
    mkdir build-$target && cd build-$target
    "$__CMAKE_WRAPPER" $target .. -DCMAKE_VERBOSE_MAKEFILE=1 \
            -DCMAKE_C_COMPILER_WORKS=1 \
            -DCMAKE_CXX_COMPILER_WORKS=1
    cmake --build . -- -j$(cpu_count)
    mkdir -p "$OUTPUT_DIR/$target"
    cd ..
    cp -r sysroot/* "$OUTPUT_DIR/$target"
done
