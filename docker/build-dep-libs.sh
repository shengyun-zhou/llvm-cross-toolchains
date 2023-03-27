#!/bin/bash
set -xe

ROOT_DIR=$(pwd)
mkdir -p build && cd build

CROSS_HOST=${CROSS_HOST:-Linux}
export CC="$HOST_CC" CXX="$HOST_CXX" RC="$HOST_RC" CPPFLAGS="$HOST_CPPFLAGS" CFLAGS="$HOST_CFLAGS" CXXFLAGS="$HOST_CXXFLAGS" LDFLAGS="$HOST_LDFLAGS"
CMAKE_FLAGS="-G Ninja -DCMAKE_VERBOSE_MAKEFILE=1 -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$BUILD_DEPS_ROOT -DCMAKE_CXX_COMPILER_WORKS=1 -DCMAKE_C_COMPILER_WORKS=1 $HOST_CMAKE_FLAGS"
if [[ $CROSS_HOST != "Windows" ]]; then
    export CFLAGS="$CFLAGS -fPIC" CXXFLAGS="$CXXFLAGS -fPIC"
fi
export CFLAGS="$CFLAGS -fvisibility=hidden" CXXFLAGS="$CXXFLAGS -fvisibility=hidden"
if [[ $CROSS_HOST == "Windows" ]]; then
    OPENSSL_TARGET=mingw64
elif [[ $CROSS_HOST == "Linux" ]]; then
    OPENSSL_TARGET=linux-generic64
elif [[ $CROSS_HOST == "Darwin" ]]; then
    OPENSSL_TARGET=darwin64-x86_64-cc
    if [[ $CROSS_PREFIX == "aarch64"* || $CROSS_PREFIX == "arm64"* ]]; then
        OPENSSL_TARGET=darwin64-arm64-cc
    fi
fi
if [[ -n "$CROSS_PREFIX" ]]; then
    export AR=$CROSS_PREFIX-ar RANLIB=$CROSS_PREFIX-ranlib
fi

if [[ -z "$SKIP_BUILD_LIBCXX" ]]; then
    # Build shared libc++
    curl "http://mirrors.ustc.edu.cn/ubuntu/pool/main/l/llvm-toolchain-14/llvm-toolchain-14_14.0.0.orig.tar.xz" -o llvm.tar.xz
    mkdir llvm-build && cd llvm-build && tar xvf ../llvm.tar.xz --strip 1
    if [[ $CROSS_HOST == "Windows" ]]; then
        LIBCXX_CMAKE_FLAGS="$LIBCXX_CMAKE_FLAGS -DLIBCXX_HAS_WIN32_THREAD_API=ON"
    elif [[ $CROSS_HOST != "Darwin" ]]; then
        LIBCXX_CMAKE_FLAGS="$LIBCXX_CMAKE_FLAGS -DLIBCXX_HAS_GCC_LIB=ON -DLIBCXX_HAS_GCC_S_LIB=OFF -DLIBCXX_HAS_ATOMIC_LIB=OFF -DLIBCXXABI_HAS_GCC_S_LIB=OFF"
    fi
    cd runtimes && mkdir build && cd build
    cmake .. $CMAKE_FLAGS -DCMAKE_C_COMPILER_TARGET=$CROSS_PREFIX -DCMAKE_CXX_COMPILER_TARGET=$CROSS_PREFIX \
        -DLLVM_ENABLE_RUNTIMES="libcxxabi;libcxx" \
        -DLLVM_LIBDIR_SUFFIX="" \
        -DLIBCXX_ENABLE_STATIC=OFF -DLIBCXX_ENABLE_SHARED=ON \
        -DLIBCXX_ENABLE_STATIC_ABI_LIBRARY=TRUE \
        -DLIBCXX_CXX_ABI=libcxxabi \
        -DLIBCXX_INCLUDE_TESTS=OFF \
        -DLIBCXX_INCLUDE_BENCHMARKS=OFF \
        -DLIBCXX_ENABLE_EXPERIMENTAL_LIBRARY=OFF \
        $LIBCXX_CMAKE_FLAGS \
        -DLIBCXXABI_ENABLE_SHARED=OFF
    cmake --build . --target install/strip
    cd "$ROOT_DIR/build"
fi

if [[ $CROSS_HOST == "Linux" ]]; then
    # Build libuuid
    curl -L "http://mirrors.ustc.edu.cn/ubuntu/pool/main/u/util-linux/util-linux_2.27.1.orig.tar.xz" -o util-linux.tar.xz && mkdir util-linux-build && \
    cd util-linux-build && tar xvf ../util-linux.tar.xz --strip 1 && ./configure $HOST_CONFIGURE_ARGS --prefix="$BUILD_DEPS_ROOT" --disable-shared --without-ncurses && make install -j$(nproc)
    cd "$ROOT_DIR/build"
elif [[ $CROSS_HOST == "Windows" ]]; then
    # Build libiconv
    curl -L "https://mirrors.ustc.edu.cn/gnu/libiconv/libiconv-1.16.tar.gz" -o libiconv.tar.gz
    mkdir libiconv-build && cd libiconv-build && tar xvf ../libiconv.tar.gz --strip 1 && ./configure $HOST_CONFIGURE_ARGS --prefix="$BUILD_DEPS_ROOT" --disable-shared && make install -j$(nproc)
    cd "$ROOT_DIR/build"
fi

# Build zlib
curl -L "http://mirrors.ustc.edu.cn/ubuntu/pool/main/z/zlib/zlib_1.2.11.dfsg.orig.tar.gz" -o zlib.tar.gz && mkdir zlib-build && \
cd zlib-build && tar xvf ../zlib.tar.gz --strip 1
CFLAGS="$CFLAGS $LDFLAGS" ./configure --prefix="$BUILD_DEPS_ROOT" --static && make install -j$(nproc)
cd "$ROOT_DIR/build"

# Build lzma
curl -L "http://mirrors.ustc.edu.cn/ubuntu/pool/main/x/xz-utils/xz-utils_5.2.5.orig.tar.xz" -o xz-utils.tar.xz && mkdir xz-utils-build && \
cd xz-utils-build && tar xvf ../xz-utils.tar.xz --strip 1 && ./configure $HOST_CONFIGURE_ARGS --prefix="$BUILD_DEPS_ROOT" --disable-shared --disable-xz --disable-xzdec --disable-doc && make install -j$(nproc)
cd "$ROOT_DIR/build"

# Build libxml2
curl -L "https://download.gnome.org/sources/libxml2/2.10/libxml2-2.10.2.tar.xz" -o libxml2.tar.xz && mkdir libxml2-build && \
cd libxml2-build && tar xvf ../libxml2.tar.xz --strip 1
mkdir build && cd build && cmake .. $CMAKE_FLAGS -DCMAKE_C_VISIBILITY_PRESET=default -DLIBXML2_WITH_PYTHON=OFF && cmake --build . --target install/strip
cd "$ROOT_DIR/build"

# Build openssl
curl -L "https://www.openssl.org/source/openssl-1.1.1j.tar.gz" -o openssl.tar.gz && mkdir openssl-build && \
cd openssl-build && tar xvf ../openssl.tar.gz --strip 1
# Patch configuration file
sed -i '/rcflag/d' Configurations/10-main.conf
./Configure $OPENSSL_TARGET no-asm no-dso no-shared no-tests --prefix="$BUILD_DEPS_ROOT" && make -j$(nproc) && make install_sw
cd "$ROOT_DIR/build"

cd "$ROOT_DIR" && rm -rf build
