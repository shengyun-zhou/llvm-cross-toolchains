#!/bin/bash
set -e
cd "$(dirname "$0")"
source config
check_build_for_targets '-wasi' || exit 0

export PATH="$OUTPUT_DIR/bin:$PATH"
SOURCE_TARBALL=emscripten-$EMSCRIPTEN_VERSION.tar.gz
mkdir -p "$SOURCE_DIR"
if [ ! -f "$SOURCE_DIR/$SOURCE_TARBALL" ]; then
    curl -sSL "https://${GITHUB_MIRROR_DOMAIN:-github.com}/emscripten-core/emscripten/archive/refs/tags/$EMSCRIPTEN_VERSION.tar.gz" -o "$SOURCE_DIR/$SOURCE_TARBALL.tmp"
    mv "$SOURCE_DIR/$SOURCE_TARBALL.tmp" "$SOURCE_DIR/$SOURCE_TARBALL"
fi
BUILD_DIR=".build-wasi-libunwind"
(test -d $BUILD_DIR && rm -rf $BUILD_DIR) || true
mkdir -p $BUILD_DIR
tar_extractor.py "$SOURCE_DIR/$SOURCE_TARBALL" -C $BUILD_DIR --strip 1
cd $BUILD_DIR && apply_patch emscripten-$EMSCRIPTEN_VERSION && cd system/lib/libunwind

for target in "${CROSS_TARGETS[@]}"; do
    if [[ $target != *"-wasi"* ]]; then
        continue
    fi
    mkdir build-$target && cd build-$target
    "$OUTPUT_DIR/bin/$target-clang" -c -v -O2 -fwasm-exceptions -DNDEBUG -D__EMSCRIPTEN__ -D_LIBUNWIND_DISABLE_VISIBILITY_ANNOTATIONS -D__USING_WASM_EXCEPTIONS__ \
        -I../include ../src/Unwind-wasm.c -o Unwind-wasm.o
    "$OUTPUT_DIR/bin/llvm-ar" rcs libunwind.a Unwind-wasm.o
    cp libunwind.a "$(target_install_prefix $target)/lib$(target_install_libdir_suffix $target)/libunwind.a"
    # Merge libunwind into compiler-rt builtins
    # WAMR provides its own exception handle function now
    if [[ $target != *"wamr"* ]]; then
        builtins_lib="$("$OUTPUT_DIR/bin/$target-clang" -rtlib=compiler-rt -print-libgcc-file-name)"
        if [[ -f "$builtins_lib" ]]; then
            "$OUTPUT_DIR/bin/llvm-ar" qcsL "$builtins_lib" libunwind.a
        fi
    fi
    cd ..
done
