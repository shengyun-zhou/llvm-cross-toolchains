#!/bin/bash
set -e
cd "$(dirname "$0")"
source config
export PATH="$OUTPUT_DIR/bin:$PATH"

SOURCE_TARBALL=llvm-project-$LLVM_VERSION.src.tar.xz
BUILD_DIR=".build-libcxx"
(test -d $BUILD_DIR && rm -rf $BUILD_DIR) || true
mkdir -p $BUILD_DIR
tar_extractor.py "$SOURCE_DIR/$SOURCE_TARBALL" -C $BUILD_DIR --strip 1

cd $BUILD_DIR
apply_patch llvm-$LLVM_VERSION
for target in "${CROSS_TARGETS[@]}"; do
    if [[ $target == *"apple"* || $target == *"msvc"* ]]; then
        # Apple: use libc++ in the SDK
        # MSVC: use MSVC c++
        continue
    fi
    # Clean installed C++ headers
    rm -rf "$(target_install_prefix $target)/include/c++" || true

    cd runtimes && mkdir build-$target && cd build-$target
    LIBDIR_SUFFIX="$(target_install_libdir_suffix $target)"
    LIBCXX_CMAKE_FLAGS=""
    if [[ $target == *"musl"* ]]; then
        LIBCXX_CMAKE_FLAGS="$LIBCXX_CMAKE_FLAGS -DLIBCXX_HAS_MUSL_LIBC=ON"
    elif [[ $target == *"mingw"* ]]; then
        LIBCXX_CMAKE_FLAGS="$LIBCXX_CMAKE_FLAGS -DLIBCXX_HAS_WIN32_THREAD_API=ON"
    elif [[ $target == "wasm"* ]]; then
        LIBCXX_CMAKE_FLAGS="$LIBCXX_CMAKE_FLAGS -DLIBCXX_HAS_MUSL_LIBC=ON"
        if [[ $target == *"wamr"* ]]; then
            # Use exception handler from WAMR
            LIBCXXABI_CMAKE_FLAGS="$LIBCXXABI_CMAKE_FLAGS -DLIBCXXABI_ENABLE_EXCEPTIONS=OFF"
        fi
        # Create empty fake libc++abi.a
        rm -f "$(target_install_prefix $target)/lib/libc++abi.a" || true
        "$OUTPUT_DIR/bin/llvm-ar" crs "$(target_install_prefix $target)/lib$LIBDIR_SUFFIX/libc++abi.a"
    
    fi

    "$__CMAKE_WRAPPER" $target .. \
        -DCMAKE_INSTALL_PREFIX="$(target_install_prefix $target)" \
        -DCMAKE_C_COMPILER_WORKS=1 \
        -DCMAKE_CXX_COMPILER_WORKS=1 \
        -DLLVM_LIBDIR_SUFFIX="$LIBDIR_SUFFIX" \
        -DLLVM_ENABLE_RUNTIMES="libcxxabi;libcxx" \
        -DLIBCXX_ENABLE_SHARED=OFF \
        -DLIBCXX_ENABLE_STATIC_ABI_LIBRARY=TRUE \
        -DLIBCXX_CXX_ABI=libcxxabi \
        -DLIBCXX_INCLUDE_TESTS=OFF \
        -DLIBCXX_INCLUDE_BENCHMARKS=OFF \
        -DLIBCXX_USE_COMPILER_RT=ON \
        $LIBCXX_CMAKE_FLAGS \
        -DLIBCXXABI_ENABLE_SHARED=OFF \
        -DLIBCXXABI_USE_COMPILER_RT=ON \
        $LIBCXXABI_CMAKE_FLAGS

    cmake --build . --target install/strip -- -j$(cpu_count)
    cd ../../
done
