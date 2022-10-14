#!/bin/bash
set -e
cd "$(dirname "$0")"
source config

SOURCE_TARBALL=llvm-project-$LLVM_VERSION.src.tar.xz
mkdir -p "$SOURCE_DIR"
if [ ! -f "$SOURCE_DIR/$SOURCE_TARBALL" ]; then
    curl -sSL "https://${GITHUB_MIRROR_DOMAIN:-github.com}/llvm/llvm-project/releases/download/llvmorg-$LLVM_VERSION/$SOURCE_TARBALL" -o "$SOURCE_DIR/$SOURCE_TARBALL.tmp"
    mv "$SOURCE_DIR/$SOURCE_TARBALL.tmp" "$SOURCE_DIR/$SOURCE_TARBALL"
fi
# Don't export these variable to prevent from being used in native LLVM tool building during cross building
unset CC CXX CFLAGS CXXFLAGS LDFLAGS
BUILD_DIR=".build-llvm"
if [ -z "$SKIP_LLVM_BUILD" ]; then
    (test -d $BUILD_DIR && rm -rf $BUILD_DIR) || true
    mkdir -p $BUILD_DIR
    tar_extractor.py "$SOURCE_DIR/$SOURCE_TARBALL" -C $BUILD_DIR --strip 1
    cd $BUILD_DIR && apply_patch llvm-$LLVM_VERSION
    cd llvm && mkdir build && cd build
    CC="$HOST_CC" CXX="$HOST_CXX" CFLAGS="$HOST_CFLAGS" CXXFLAGS="$HOST_CXXFLAGS" LDFLAGS="$HOST_LDFLAGS" \
    cmake .. -Wno-dev -G Ninja $LLVM_CMAKE_FLAGS $HOST_CMAKE_FLAGS -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$OUTPUT_DIR" \
        -DCROSS_TOOLCHAIN_FLAGS_NATIVE="" -DLLVM_ENABLE_PROJECTS="clang;lld" -DLLVM_ENABLE_TERMINFO=OFF -DLLVM_ENABLE_LIBXML2=FORCE_ON \
        -DLLVM_INCLUDE_EXAMPLES=OFF -DLLVM_INCLUDE_BENCHMARKS=OFF \
        -DLLVM_BUILD_LLVM_DYLIB=ON -DLLVM_BUILD_STATIC=OFF -DLLVM_LINK_LLVM_DYLIB=ON \
        -DLLVM_TARGETS_TO_BUILD="${LLVM_TARGETS_TO_BUILD:-Mips;ARM;AArch64;X86;RISCV;WebAssembly}"
else
    cd "$BUILD_DIR/llvm/build"
fi

cmake --build . --target install/strip -- -j$(cpu_count)
cmake --build . --target clang-tblgen -- -j$(cpu_count)
cp bin/clang-tblgen${CROSS_EXEC_SUFFIX} "$OUTPUT_DIR/bin/"
if [[ -n "$HOST_RUNTIME_LIBS" ]]; then
    if [[ $CROSS_HOST == "Windows" ]]; then
        cp -L $HOST_RUNTIME_LIBS "$OUTPUT_DIR/bin/"
    else
        cp -L $HOST_RUNTIME_LIBS "$OUTPUT_DIR/lib/"
    fi
fi
if [[ -f "NATIVE/bin/llvm-config${EXEC_SUFFIX}" ]]; then
    cp "NATIVE/bin/llvm-config${EXEC_SUFFIX}" "$OUTPUT_DIR/bin/llvm-config-native${EXEC_SUFFIX}"
fi
