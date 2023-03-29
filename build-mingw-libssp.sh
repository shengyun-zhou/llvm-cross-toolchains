#!/bin/bash
# Ref: https://github.com/mstorsjo/llvm-mingw/blob/20220906/build-libssp.sh
set -e
cd "$(dirname "$0")"
source config
export PATH="$OUTPUT_DIR/bin:$PATH"
check_build_for_targets '-mingw' || exit 0

LIBSSP_VERSION=7.3.0
SOURCE_TARBALL=libssp-$LIBSSP_VERSION.tar.bz2
mkdir -p "$SOURCE_DIR"
if [ ! -f "$SOURCE_DIR/$SOURCE_TARBALL" ]; then
    curl -sSL "https://gitlab.com/watched/gcc-mirror/gcc/-/archive/releases/gcc-$LIBSSP_VERSION/gcc-releases-gcc-$LIBSSP_VERSION.tar.bz2?path=libssp" -o "$SOURCE_DIR/$SOURCE_TARBALL.tmp"
    mv "$SOURCE_DIR/$SOURCE_TARBALL.tmp" "$SOURCE_DIR/$SOURCE_TARBALL"
fi
BUILD_DIR=".build-mingw-libssp"
(test -d $BUILD_DIR && rm -rf $BUILD_DIR) || true
mkdir -p $BUILD_DIR
tar_extractor.py "$SOURCE_DIR/$SOURCE_TARBALL" -C $BUILD_DIR --strip 1
cd $BUILD_DIR
cd libssp
cp ../../build-tools/libssp-Makefile Makefile

# gcc/libssp's configure script runs checks for flags that clang doesn't
# implement. We actually just need to set a few HAVE defines and compile
# the .c sources.
cp config.h.in config.h
for i in HAVE_FCNTL_H HAVE_INTTYPES_H HAVE_LIMITS_H HAVE_MALLOC_H \
    HAVE_MEMMOVE HAVE_MEMORY_H HAVE_MEMPCPY HAVE_STDINT_H HAVE_STDIO_H \
    HAVE_STDLIB_H HAVE_STRINGS_H HAVE_STRING_H HAVE_STRNCAT HAVE_STRNCPY \
    HAVE_SYS_STAT_H HAVE_SYS_TYPES_H HAVE_UNISTD_H HAVE_USABLE_VSNPRINTF \
    HAVE_HIDDEN_VISIBILITY; do
    cat config.h | sed 's/^#undef '$i'$/#define '$i' 1/' > tmp
    mv tmp config.h
done
cat ssp/ssp.h.in | sed 's/@ssp_have_usable_vsnprintf@/define/' > ssp/ssp.h

for target in "${CROSS_TARGETS[@]}"; do
    if [[ $target == *"-mingw"* ]]; then
        mkdir build-$target && cd build-$target
        make -f ../Makefile -j$(cpu_count) CROSS=${target}-
        cp libssp.a libssp_nonshared.a "$(target_install_prefix $target)/lib"
        cd ..
    fi
done

