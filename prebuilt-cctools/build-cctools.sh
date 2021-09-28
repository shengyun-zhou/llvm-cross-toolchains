#!/bin/bash
# Ref: https://github.com/tpoechtrager/osxcross

set -e
cd "$(dirname "$0")"
PRE_PWD="$(pwd)"
cd ..
source config

check_build_for_targets 'apple-' || exit 0
BUILD_DIR=".build-cctools"

# Don't export these variable to prevent from being used in native LLVM tool building during cross building
unset CC CXX CFLAGS CXXFLAGS LDFLAGS

(test -d $BUILD_DIR && rm -rf $BUILD_DIR) || true
mkdir -p $BUILD_DIR && cd $BUILD_DIR
# Build Apple libtapi
SOURCE_TARBALL=tapi-1100.0.11-664b841.tar.gz
mkdir -p "$SOURCE_DIR"
if [ ! -f "$SOURCE_DIR/$SOURCE_TARBALL" ]; then
    curl -sSL "https://${GITHUB_MIRROR_DOMAIN:-github.com}/tpoechtrager/apple-libtapi/archive/refs/heads/1100.0.11.tar.gz" -o "$SOURCE_DIR/$SOURCE_TARBALL.tmp"
    mv "$SOURCE_DIR/$SOURCE_TARBALL.tmp" "$SOURCE_DIR/$SOURCE_TARBALL"
fi
mkdir tapi-build && cd tapi-build && tar_extractor.py "$SOURCE_DIR/$SOURCE_TARBALL" --strip 1
apply_patch apple-libtapi
mkdir build && cd build

TAPI_CMAKE_EXTRA_FLAGS=""
if [[ "$CROSS_HOST" != "$BUILD_HOST" ]]; then
    TAPI_CMAKE_EXTRA_FLAGS="$TAPI_CMAKE_EXTRA_FLAGS -DCLANG_TABLEGEN_EXE=$(pwd)/NATIVE/bin/clang-tblgen${EXEC_SUFFIX}"
fi
CC="${HOST_CC:-clang}" CXX="${HOST_CXX:-clang++}" CFLAGS="$HOST_CFLAGS" CXXFLAGS="$HOST_CXXFLAGS" LDFLAGS="$HOST_LDFLAGS" \
CXXFLAGS="$CXXFLAGS -I../src/llvm/projects/clang/include -Iprojects/clang/include" cmake ../src/llvm -Wno-dev -G Ninja $LLVM_CMAKE_FLAGS $HOST_CMAKE_FLAGS \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$(pwd)/../../cctools-install" \
    -DCROSS_TOOLCHAIN_FLAGS_NATIVE="" \
    -DLLVM_TARGETS_TO_BUILD="ARM;AArch64;X86" -DLLVM_INCLUDE_TESTS=OFF -DLLVM_ENABLE_TERMINFO=OFF \
    -DTAPI_REPOSITORY_STRING=1100.0.11 \
    -DTAPI_FULL_VERSION=11.0.0 $TAPI_CMAKE_EXTRA_FLAGS

cmake --build . --target clangBasic -- -j$(cpu_count)
cmake --build . --target libtapi -- -j$(cpu_count)
if [ -n "$BUILD_LIBLTO" ]; then
    cmake --build . --target LTO -- -j$(cpu_count)
    cmake --build . --target install-LTO
    mkdir -p "$(pwd)/../../cctools-install/lib-llvm"
    mv "$(pwd)/../../cctools-install/lib/"libLTO* "$(pwd)/../../cctools-install/lib-llvm"
fi
cmake --build . --target install-libtapi -- -j$(cpu_count)
cmake --build . --target install-tapi-headers -- -j$(cpu_count)
cd ../../

export CC="${HOST_CC:-clang}"
export CXX="${HOST_CXX:-clang++}"
export CPPFLAGS="$HOST_CPPFLAGS"
export CXXFLAGS="$HOST_CXXFLAGS -Qunused-arguments"
export CFLAGS="$HOST_CFLAGS -Qunused-arguments"
export LDFLAGS="$HOST_LDFLAGS -pthread"
if [[ $CROSS_HOST == "Linux" ]]; then
    export LDFLAGS="$LDFLAGS -Wl,-rpath,'\$\${ORIGIN}/../lib'"
elif [[ $CROSS_HOST == "Darwin" ]]; then
    export LDFLAGS="$LDFLAGS -w -Wl,-rpath,@loader_path/../lib"
fi
if [[ "$CROSS_HOST" != "Darwin" ]]; then
    # Build xar
    SOURCE_TARBALL=xar-2b9a4ab7.tar.gz
    if [ ! -f "$SOURCE_DIR/$SOURCE_TARBALL" ]; then
        curl -sSL "https://${GITHUB_MIRROR_DOMAIN:-github.com}/tpoechtrager/xar/archive/2b9a4ab7003f1db8c54da4fea55fcbb424fdecb0.tar.gz" -o "$SOURCE_DIR/$SOURCE_TARBALL.tmp"
        mv "$SOURCE_DIR/$SOURCE_TARBALL.tmp" "$SOURCE_DIR/$SOURCE_TARBALL"
    fi
    mkdir xar-build && cd xar-build
    tar_extractor.py "$SOURCE_DIR/$SOURCE_TARBALL" --strip 1
    xar/configure $HOST_CONFIGURE_ARGS $CONFIGURE_ARGS --prefix="$(pwd)/../cctools-install" --disable-static
    make -j$(cpu_count)
    make install -j$(cpu_count)
    rm -f "../cctools-install/bin/xar" || true
    cd ..
fi

# Build cctools
SOURCE_TARBALL=cctools-port-973.0.1-ld64-609.tar.gz
if [ ! -f "$SOURCE_DIR/$SOURCE_TARBALL" ]; then
    curl -sSL "https://${GITHUB_MIRROR_DOMAIN:-github.com}/tpoechtrager/cctools-port/archive/refs/heads/973.0.1-ld64-609.tar.gz" -o "$SOURCE_DIR/$SOURCE_TARBALL.tmp"
    mv "$SOURCE_DIR/$SOURCE_TARBALL.tmp" "$SOURCE_DIR/$SOURCE_TARBALL"
fi
mkdir cctools-build && cd cctools-build
tar_extractor.py "$SOURCE_DIR/$SOURCE_TARBALL" --strip 1
apply_patch cctools
CCTOOLS_CONFIGURE_ARGS="$HOST_CONFIGURE_ARGS $CONFIGURE_ARGS"
if [[ "$CROSS_HOST" != "Darwin" ]]; then
    CCTOOLS_CONFIGURE_ARGS="$CCTOOLS_CONFIGURE_ARGS --with-libxar=$(pwd)/../cctools-install"
fi
PROGRAM_PREFIX="cctools-" cctools/configure $CCTOOLS_CONFIGURE_ARGS --prefix="$(pwd)/../cctools-install" --program-prefix="cctools-" \
    --enable-lto-support --with-libtapi="$(pwd)/../cctools-install" --with-llvm-config="${HOST_LLVM_CONFIG:-llvm-config${EXEC_SUFFIX}}"
make -j$(cpu_count)
make install -j$(cpu_count)
cd ..
for binfile in cctools-install/bin/*; do
    "${HOST_STRIP:-strip}" "$binfile"
done
mv cctools-install/bin cctools-install/cctools-bin
if [[ -n "$HOST_RUNTIME_LIBS" ]]; then
    mkdir -p cctools-install/lib-llvm
    cp -L $HOST_RUNTIME_LIBS cctools-install/lib-llvm/
fi
TAR_DIRS="./lib ./cctools-bin"
if [ -d cctools-install/lib-llvm ]; then
    TAR_DIRS="$TAR_DIRS ./lib-llvm"
fi
tar cvzf "$PRE_PWD/cctools.tar.gz" -C cctools-install $TAR_DIRS
