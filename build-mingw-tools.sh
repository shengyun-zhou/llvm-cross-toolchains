#!/bin/bash
set -e
cd "$(dirname "$0")"
source config
check_build_for_targets '-mingw' || exit 0

SOURCE_TARBALL=mingw-w64-v$MINGW_VERSION.tar.bz2
mkdir -p "$SOURCE_DIR"
if [ ! -f "$SOURCE_DIR/$SOURCE_TARBALL" ]; then
    curl -sSL "https://sourceforge.net/projects/mingw-w64/files/mingw-w64/mingw-w64-release/$SOURCE_TARBALL" -o "$SOURCE_DIR/$SOURCE_TARBALL.tmp"
    mv "$SOURCE_DIR/$SOURCE_TARBALL.tmp" "$SOURCE_DIR/$SOURCE_TARBALL"
fi
BUILD_DIR=".build-mingw"
(test -d $BUILD_DIR && rm -rf $BUILD_DIR) || true
mkdir -p $BUILD_DIR
tar_extractor.py "$SOURCE_DIR/$SOURCE_TARBALL" -C $BUILD_DIR --strip 1
cd $BUILD_DIR
apply_patch mingw-$MINGW_VERSION
cd mingw-w64-tools

export CC="$HOST_CC"
export CXX="$HOST_CXX"
# LDFLAGS may not work
export CFLAGS="$HOST_CFLAGS $HOST_LDFLAGS"
export CXXFLAGS="$HOST_CXXFLAGS"
export LDFLAGS="$HOST_LDFLAGS"

for target in "${CROSS_TARGETS[@]}"; do
    if [[ $target == *"-mingw"* ]]; then
        for d in gendef genidl genlib genpeimg widl; do
            if [ -d "$d" ]; then
                cd "$d" && mkdir build-$target && cd build-$target
                ../configure $HOST_CONFIGURE_ARGS $CONFIGURE_ARGS --target=$target --program-prefix=${target}- --prefix="$OUTPUT_DIR"
                make -j$(cpu_count)
                make install
                cd ../../
            fi
        done
    fi
done

