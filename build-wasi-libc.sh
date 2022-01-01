#!/bin/bash
set -e
cd "$(dirname "$0")"
source config
check_build_for_targets '-wasi' || exit 0

export PATH="$OUTPUT_DIR/bin:$PATH"
SOURCE_TARBALL=wasi-libc-${WASI_LIBC_COMMIT_ID:0:8}.tar.gz
mkdir -p "$SOURCE_DIR"
if [ ! -f "$SOURCE_DIR/$SOURCE_TARBALL" ]; then
    curl -sSL "https://${GITHUB_MIRROR_DOMAIN:-github.com}/WebAssembly/wasi-libc/archive/$WASI_LIBC_COMMIT_ID.tar.gz" -o "$SOURCE_DIR/$SOURCE_TARBALL.tmp"
    mv "$SOURCE_DIR/$SOURCE_TARBALL.tmp" "$SOURCE_DIR/$SOURCE_TARBALL"
fi
BUILD_DIR=".build-wasi"
(test -d $BUILD_DIR && rm -rf $BUILD_DIR) || true
mkdir -p $BUILD_DIR
tar_extractor.py "$SOURCE_DIR/$SOURCE_TARBALL" -C $BUILD_DIR --strip 1
cd $BUILD_DIR
apply_patch wasi-libc-${WASI_LIBC_COMMIT_ID:0:8}

make -j$(cpu_count)
# Supply some header files
cp libc-top-half/musl/include/pthread.h sysroot/include

for target in "${CROSS_TARGETS[@]}"; do
    if [[ $target != *"-wasi"* ]]; then
        continue
    fi
    mkdir -p "$OUTPUT_DIR/$target"
    cp -r sysroot/* "$OUTPUT_DIR/$target"
    if [[ $target == *"wamr"* ]]; then
        cp -r ../wamr/include/* "$OUTPUT_DIR/$target/include" || true
        cat ../wamr/defined-symbols.txt >> "$OUTPUT_DIR/$target/share/wasm32-wasi/defined-symbols.txt"
        "$OUTPUT_DIR/bin/$target-clang" -c -v -O2 -DNDEBUG ../wamr/src/wamr_libc.c -o wamr_libc.o
        # Recompile dlmalloc with thread-safety support
        "$OUTPUT_DIR/bin/$target-clang" -c -v -O2 -DNDEBUG -DUSE_LOCKS=1 -DUSE_SPIN_LOCKS=0 dlmalloc/src/dlmalloc.c -o dlmalloc.o
        "$OUTPUT_DIR/bin/llvm-ar" rs "$OUTPUT_DIR/$target/lib/wasm32-wasi/libc.a" dlmalloc.o wamr_libc.o
    fi
done
