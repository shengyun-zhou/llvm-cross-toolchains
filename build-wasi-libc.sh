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
# Remove -Werror compile flag
sed -i.bak "s/-Werror//g" Makefile
# Remove symbol different checking
sed -i.bak "/diff -wur/d" Makefile

for target in "${CROSS_TARGETS[@]}"; do
    if [[ $target != *"-wasi"* ]]; then
        continue
    fi
    rm -rf build sysroot || true
    make WASM_CC="$OUTPUT_DIR/bin/$target-clang" WASM_AR="$OUTPUT_DIR/bin/$target-ar" WASM_NM="$OUTPUT_DIR/bin/$target-nm"  -j$(cpu_count)
    mkdir -p "$OUTPUT_DIR/$target"
    cp -r sysroot/* "$OUTPUT_DIR/$target"
    if [[ $target == *"wamr"* ]]; then
        LIBDIR="$(target_install_prefix $target)/lib$(target_install_libdir_suffix $target)"
        # Merge some emulated libs into libc
        "$OUTPUT_DIR/bin/llvm-ar" qcsL "$LIBDIR/libc.a" "$LIBDIR/libwasi-emulated-signal.a"
        cp -r ../wamr/include/* "$OUTPUT_DIR/$target/include" || true
        cat ../wamr/defined-symbols.txt >> "$OUTPUT_DIR/$target/share/wasm32-wasi/defined-symbols.txt"
        mkdir build-$target && cd build-$target
        # Build extend libc for WAMR
        # Hack include directory temporarily
        mv ../libc-top-half/musl/include include.bak
        cp -r "$OUTPUT_DIR/$target/include" ../libc-top-half/musl
        "$__CMAKE_WRAPPER" $target ../../wamr -DCMAKE_VERBOSE_MAKEFILE=1 \
            -DCMAKE_C_COMPILER_WORKS=1 \
            -DCMAKE_CXX_COMPILER_WORKS=1 \
            -DWASI_LIBC_SOURCE="$(dirname "$(pwd)")" \
            -DPREBUILT_WASI_LIBC="$LIBDIR/libc.a"
        cmake --build . -- -j$(cpu_count)
        rm -rf ../libc-top-half/musl/include && mv include.bak ../libc-top-half/musl/include
        cd ..
    fi
done
