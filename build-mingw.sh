#!/bin/bash
set -e
cd "$(dirname "$0")"
source config
check_build_for_targets '-mingw' || exit 0

export PATH="$OUTPUT_DIR/bin:$PATH"
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

for target in "${CROSS_TARGETS[@]}"; do
    if [[ $target == *"-mingw"* ]]; then
        if [ -n "$LIBC_STARTFILE_STAGE" ]; then
            echo "Install MinGW header and start files for target $target"
            cd mingw-w64-headers && mkdir build-$target && cd build-$target
            ../configure $CONFIGURE_ARGS --prefix="$(target_install_prefix $target)" --enable-idl --with-default-win32-winnt=0x601 --with-default-msvcrt=msvcrt
            make -j$(cpu_count)
            make install
            MINGW_CRT_CONFIG_FLAGS=""
            case $target in
            aarch64*|arm64*)
                MINGW_CRT_CONFIG_FLAGS="$MINGW_CRT_CONFIG_FLAGS --disable-lib32 --disable-lib64 --enable-libarm64"
                ;;
            arm*)
                MINGW_CRT_CONFIG_FLAGS="$MINGW_CRT_CONFIG_FLAGS --disable-lib32 --disable-lib64 --enable-libarm32"
                ;;
            i*86*)
                MINGW_CRT_CONFIG_FLAGS="$MINGW_CRT_CONFIG_FLAGS --enable-lib32 --disable-lib64"
                ;;
            x86_64*)
                MINGW_CRT_CONFIG_FLAGS="$MINGW_CRT_CONFIG_FLAGS --disable-lib32 --enable-lib64"
                ;;
            esac
            cd ../../mingw-w64-crt && mkdir build-$target && cd build-$target
            ../configure $CONFIGURE_ARGS --prefix="$(target_install_prefix $target)" --host=$target --with-default-msvcrt=msvcrt $MINGW_CRT_CONFIG_FLAGS
            make -j$(cpu_count)
            make install
            cd ../../
        else
            cd mingw-w64-libraries/winpthreads && mkdir build-$target && cd build-$target
            echo "Install MinGW libraries for target $target"
            ../configure $CONFIGURE_ARGS --host=$target --prefix="$(target_install_prefix $target)" --disable-shared
            make -j$(cpu_count)
            make install
            cd ../../../
        fi
    fi
done

