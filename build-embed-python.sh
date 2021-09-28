#!/bin/bash
set -e
cd "$(dirname "$0")"
source config

if [[ "$CROSS_HOST" == "Windows" ]]; then
    WIN_PYTHON_ARCH="${WIN_PYTHON_ARCH:-amd64}"
    SOURCE_TARBALL=python-3.9.7-embed-$WIN_PYTHON_ARCH.zip
    mkdir -p "$SOURCE_DIR"
    if [ ! -f "$SOURCE_DIR/$SOURCE_TARBALL" ]; then
        curl -sSL "https://www.python.org/ftp/python/3.9.7/$SOURCE_TARBALL" -o "$SOURCE_DIR/$SOURCE_TARBALL.tmp"
        mv "$SOURCE_DIR/$SOURCE_TARBALL.tmp" "$SOURCE_DIR/$SOURCE_TARBALL"
    fi
    rm -rf "$OUTPUT_DIR/python_embed" || true
    mkdir -p "$OUTPUT_DIR/python_embed" && unzip -q "$SOURCE_DIR/$SOURCE_TARBALL" -d "$OUTPUT_DIR/python_embed"
    # Remove it to prevent custom python module cannot be imported
    rm -f "$OUTPUT_DIR/python_embed/python39._pth"
    exit 0
fi

BUILD_DIR=".build-python"
(test -d $BUILD_DIR && rm -rf $BUILD_DIR) || true
mkdir -p $BUILD_DIR

NATIVE_PYTHON_VERSION=3.9
PYTHON_SOURCE_TARBALL=Python-3.9.7.tar.xz
PYTHON_DOWNLOAD_URL=http://mirrors.ustc.edu.cn/ubuntu/pool/main/p/python3.9/python3.9_3.9.7.orig.tar.xz
# Disable ipv6 due to getaddrinfo() bug in old glibc
PYTHON_COMMON_CONFIGURE_ARGS="--without-ensurepip --disable-ipv6 --with-system-ffi"

SOURCE_TARBALL=$PYTHON_SOURCE_TARBALL
mkdir -p "$SOURCE_DIR"
if [ ! -f "$SOURCE_DIR/$SOURCE_TARBALL" ]; then
    curl -sSL "$PYTHON_DOWNLOAD_URL" -o "$SOURCE_DIR/$SOURCE_TARBALL.tmp"
    mv "$SOURCE_DIR/$SOURCE_TARBALL.tmp" "$SOURCE_DIR/$SOURCE_TARBALL"
fi
tar_extractor.py "$SOURCE_DIR/$SOURCE_TARBALL" -C $BUILD_DIR --strip 1
cd $BUILD_DIR
mkdir build && cd build

if [[ "$BUILD_HOST" != "$CROSS_HOST" ]]; then
    CROSS_COMPILE_PYTHON=1
fi

if [[ -n "$CROSS_COMPILE_PYTHON" ]]; then
    NATIVE_PYTHON_EXEC=""
    for exe in python${NATIVE_PYTHON_VERSION} python3 python; do
        if [ -x "$(command -v $exe)" ]; then
            NATIVE_PYTHON_EXEC=$exe
        fi
    done
    if [[ "$($NATIVE_PYTHON_EXEC -c 'import sys; print(".".join(map(str, sys.version_info[:2])))')" != $NATIVE_PYTHON_VERSION ]]; then
        # Build temp python for native first
        mkdir build-native-python
        tar_extractor.py "$SOURCE_DIR/$SOURCE_TARBALL" -C build-native-python --strip 1
        cd build-native-python
        mkdir build && cd build

        ../configure --prefix="$(pwd)/../../../.native-python-install" $PYTHON_COMMON_CONFIGURE_ARGS
        make -j$(cpu_count) && make install -j$(cpu_count)
        cd ../../
        export PATH="$(pwd)/../.native-python-install/bin:$PATH"
    fi
fi

PYTHON_INSTALL_PREFIX="$(pwd)/python-install"
export CC="$HOST_CC"
export CXX="$HOST_CXX"
export CPPFLAGS="$HOST_CPPFLAGS"
export CFLAGS="$HOST_CFLAGS $HOST_LDFLAGS"
export CXXFLAGS="$HOST_CXXFLAGS"
export LDFLAGS="$HOST_LDFLAGS -Wl,-s"

# Configure hack for cross build
echo 'ac_cv_file__dev_ptmx=yes' >> config.cache
echo 'ac_cv_file__dev_ptc=no' >> config.cache

# Disable ipv6 due to getaddrinfo() bug in old glibc
../configure $HOST_CONFIGURE_ARGS $CONFIGURE_ARGS --build="$(../config.guess)" --prefix="$PYTHON_INSTALL_PREFIX" \
    --config-cache $PYTHON_COMMON_CONFIGURE_ARGS $EMBED_PYTHON_CONFIGURE_ARGS
make -j$(cpu_count) && make install -j$(cpu_count)

# Clean unused files
rm -rf python-install/lib/*.a || true
rm -rf python-install/lib/pkgconfig || true
rm -rf python-install/lib/python*/test || true
rm -rf python-install/lib/python*/config-* || true

rm -rf "$OUTPUT_DIR/python_embed" || true
mkdir -p "$OUTPUT_DIR/python_embed" && cp -r python-install/bin python-install/lib "$OUTPUT_DIR/python_embed"
