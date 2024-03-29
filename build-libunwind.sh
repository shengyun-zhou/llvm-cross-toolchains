#!/bin/bash
set -e
cd "$(dirname "$0")"
source config
export PATH="$OUTPUT_DIR/bin:$PATH"

SOURCE_TARBALL=llvm-project-$LLVM_VERSION.src.tar.xz
BUILD_DIR=".build-libunwind"
(test -d $BUILD_DIR && rm -rf $BUILD_DIR) || true
mkdir -p $BUILD_DIR
tar_extractor.py "$SOURCE_DIR/$SOURCE_TARBALL" -C $BUILD_DIR --strip 1
cd $BUILD_DIR
apply_patch llvm-$LLVM_VERSION
cd runtimes

for target in "${CROSS_TARGETS[@]}"; do
    if [[ $target == *"apple"* || $target == *"msvc"* || $target == "wasm"* ]]; then
        # Apple: use libunwind in the SDK
        # MSVC: do not use it now
        # WASM: build libunwind from Emscripten source code
        continue
    fi
    mkdir build-$target && cd build-$target
    LIBUNWIND_CXXFLAGS=""

    CXXFLAGS="$LIBUNWIND_CXXFLAGS" "$__CMAKE_WRAPPER" $target .. \
        -DCMAKE_INSTALL_PREFIX="$(target_install_prefix $target)" \
        -DCMAKE_C_COMPILER_WORKS=1 \
        -DCMAKE_CXX_COMPILER_WORKS=1 \
        -DLLVM_LIBDIR_SUFFIX="$(target_install_libdir_suffix $target)" \
        -DLLVM_ENABLE_RUNTIMES="libunwind" \
        -DLIBUNWIND_USE_COMPILER_RT=ON \
        -DLIBUNWIND_ENABLE_SHARED=OFF
    cmake --build . --target install/strip -- -j$(cpu_count)
    cd ..
    # Merge libunwind into compiler-rt builtins
    if [[ -f "$(target_install_prefix $target)/lib/libunwind.a" ]]; then
        builtins_lib="$("$OUTPUT_DIR/bin/$target-clang" -rtlib=compiler-rt -print-libgcc-file-name)"
        if [[ -f "$builtins_lib" ]]; then
            "$OUTPUT_DIR/bin/llvm-ar" qcsL "$builtins_lib" "$(target_install_prefix $target)/lib/libunwind.a"
            if [[ $target == *"freebsd"* ]]; then
                cp "$builtins_lib" "$(target_install_prefix $target)/lib/libgcc.a"
                ln -sf libunwind.a "$(target_install_prefix $target)/lib/libgcc_eh.a"
            fi
        fi
    fi
done

