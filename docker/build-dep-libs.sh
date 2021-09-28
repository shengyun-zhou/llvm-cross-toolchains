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

if [[ -z "$SKIP_BUILD_LIBCXX" ]]; then
    # Build shared libc++
    curl "http://mirrors.ustc.edu.cn/ubuntu/pool/main/l/llvm-toolchain-12/llvm-toolchain-12_12.0.1.orig.tar.xz" -o llvm.tar.xz
    mkdir llvm-build && cd llvm-build && tar xvf ../llvm.tar.xz --strip 1
    if [[ $CROSS_HOST == "Windows" ]]; then
        LIBCXX_CMAKE_FLAGS="$LIBCXX_CMAKE_FLAGS -DLIBCXX_HAS_WIN32_THREAD_API=ON"
    fi
    if [[ $CROSS_HOST != "Darwin" ]]; then
        # Don't link libatomic
        cd libunwind && mkdir build && cd build
        cmake .. $CMAKE_FLAGS -DLIBUNWIND_ENABLE_SHARED=OFF
        cmake --build . --target install/strip
        cd ../../
        LIBCXX_CMAKE_FLAGS="$LIBCXX_CMAKE_FLAGS -DLIBCXX_USE_COMPILER_RT=ON -DLIBCXXABI_USE_LLVM_UNWINDER=ON"
    fi
    cd libcxx && mkdir build && cd build
    cmake .. $CMAKE_FLAGS -DLIBCXX_ENABLE_STATIC=OFF \
        -DLIBCXX_ENABLE_STATIC_ABI_LIBRARY=TRUE \
        -DLIBCXX_CXX_ABI=libcxxabi \
        -DLIBCXX_CXX_ABI_INCLUDE_PATHS=../../libcxxabi/include \
        -DLIBCXX_CXX_ABI_LIBRARY_PATH=../../libcxxabi/build/lib \
        -DLIBCXX_INCLUDE_TESTS=OFF -DLIBCXX_ENABLE_EXPERIMENTAL_LIBRARY=OFF \
        -DLIBCXX_LIBDIR_SUFFIX="" \
        $LIBCXX_CMAKE_FLAGS
    cmake --build . --target generate-cxx-headers
    cd ../../libcxxabi && mkdir build && cd build
    cmake .. $CMAKE_FLAGS \
        -DLIBCXXABI_ENABLE_SHARED=OFF -DLIBCXX_ENABLE_STATIC_ABI_LIBRARY=TRUE -DLIBCXX_ENABLE_SHARED=ON \
        -DLIBCXXABI_LIBCXX_INCLUDES=../../libcxx/build/include/c++/v1
    cmake --build .
    cd ../../libcxx/build && cmake --build . --target install/strip
    cd "$ROOT_DIR/build"
fi

if [[ $CROSS_HOST == "Linux" ]]; then
    # Build libuuid
    curl -L "http://mirrors.ustc.edu.cn/ubuntu/pool/main/u/util-linux/util-linux_2.20.1.orig.tar.gz" -o util-linux.tar.gz && mkdir util-linux-build && \
    cd util-linux-build && tar xvf ../util-linux.tar.gz --strip 1 && ./configure $HOST_CONFIGURE_ARGS --prefix="$BUILD_DEPS_ROOT" --disable-shared --without-ncurses && make install -j$(nproc)
    cd "$ROOT_DIR/build"
elif [[ $CROSS_HOST == "Windows" ]]; then
    # Build libiconv
    curl -L "https://mirrors.tuna.tsinghua.edu.cn/gnu/libiconv/libiconv-1.16.tar.gz" -o libiconv.tar.gz
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
curl -L "http://mirrors.ustc.edu.cn/ubuntu/pool/main/libx/libxml2/libxml2_2.9.10%2Bdfsg.orig.tar.xz" -o libxml2.tar.gz && mkdir libxml2-build && \
cd libxml2-build && tar xvf ../libxml2.tar.gz --strip 1 && ./configure $HOST_CONFIGURE_ARGS --prefix="$BUILD_DEPS_ROOT" --disable-shared --with-zlib="$BUILD_DEPS_ROOT" --with-lzma="$BUILD_DEPS_ROOT" --without-python && make install -j$(nproc)
cd "$ROOT_DIR/build"

# Build libffi
curl -L "http://mirrors.ustc.edu.cn/ubuntu/pool/main/libf/libffi/libffi_3.3.orig.tar.gz" -o libffi.tar.gz
mkdir libffi-build && cd libffi-build && tar xvf ../libffi.tar.gz --strip 1 && ./configure $HOST_CONFIGURE_ARGS --prefix="$BUILD_DEPS_ROOT" --disable-shared && make install -j$(nproc)
cd "$ROOT_DIR/build"

# Build openssl
curl -L "http://mirrors.ustc.edu.cn/ubuntu/pool/main/o/openssl/openssl_1.1.1j.orig.tar.gz" -o openssl.tar.gz && mkdir openssl-build && \
cd openssl-build && tar xvf ../openssl.tar.gz --strip 1 && ./Configure $OPENSSL_TARGET no-dso no-shared no-tests --prefix="$BUILD_DEPS_ROOT" && make -j$(nproc) && make install_sw
cd "$ROOT_DIR/build"

cd "$ROOT_DIR" && rm -rf build
