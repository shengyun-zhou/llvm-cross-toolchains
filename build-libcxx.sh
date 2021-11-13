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
    if [[ $target == *"apple"* || $target == *"msvc"* || $target == *"emscripten"* ]]; then
        # Apple: use libc++ in the SDK
        # MSVC: use MSVC c++
        # Emscripten: use libc++ built by emcc
        continue
    fi
    # Clean installed C++ headers
    rm -rf "$(target_install_prefix $target)/include/c++" || true

    cd libcxx && mkdir build-$target && cd build-$target
    LIBCXX_CMAKE_FLAGS=""
    if [[ $target == *"musl"* ]]; then
        LIBCXX_CMAKE_FLAGS="$LIBCXX_CMAKE_FLAGS -DLIBCXX_HAS_MUSL_LIBC=ON"
    elif [[ $target == *"mingw"* ]]; then
        LIBCXX_CMAKE_FLAGS="$LIBCXX_CMAKE_FLAGS -DLIBCXX_HAS_WIN32_THREAD_API=ON"
    fi
    "$__CMAKE_WRAPPER" $target .. \
        -DCMAKE_INSTALL_PREFIX="$(target_install_prefix $target)" \
        -DCMAKE_C_COMPILER_WORKS=1 \
        -DCMAKE_CXX_COMPILER_WORKS=1 \
        -DLIBCXX_ENABLE_SHARED=OFF \
        -DLIBCXX_ENABLE_STATIC_ABI_LIBRARY=TRUE \
        -DLIBCXX_CXX_ABI=libcxxabi \
        -DLIBCXX_CXX_ABI_INCLUDE_PATHS=../../libcxxabi/include \
        -DLIBCXX_CXX_ABI_LIBRARY_PATH=../../libcxxabi/build-$target/lib \
        -DLIBCXX_INCLUDE_TESTS=OFF \
        $LIBCXX_CMAKE_FLAGS

    cmake --build . --target generate-cxx-headers -- -j$(cpu_count)

    cd ../../libcxxabi && mkdir build-$target && cd build-$target
    "$__CMAKE_WRAPPER" $target .. \
        -DCMAKE_INSTALL_PREFIX="$(target_install_prefix $target)" \
        -DCMAKE_C_COMPILER_WORKS=1 \
        -DCMAKE_CXX_COMPILER_WORKS=1 \
        -DLIBCXXABI_ENABLE_SHARED=OFF \
        -DLIBCXXABI_LIBCXX_INCLUDES=../../libcxx/build-$target/include/c++/v1 \
        -DLIBCXXABI_USE_COMPILER_RT=ON

    cmake --build . -- -j$(cpu_count)
    cd ../../libcxx/build-$target
    cmake --build . --target install/strip -- -j$(cpu_count)
    cd ../../
done
