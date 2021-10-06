#!/bin/bash
set -e
cd "$(dirname "$0")"
source config
check_build_for_targets '-musl' || exit 0

export PATH="$OUTPUT_DIR/bin:$PATH"
SOURCE_TARBALL=musl-$MUSL_VERSION.tar.gz
mkdir -p "$SOURCE_DIR"
if [ ! -f "$SOURCE_DIR/$SOURCE_TARBALL" ]; then
    curl -sSL "https://musl.libc.org/releases/$SOURCE_TARBALL" -o "$SOURCE_DIR/$SOURCE_TARBALL.tmp"
    mv "$SOURCE_DIR/$SOURCE_TARBALL.tmp" "$SOURCE_DIR/$SOURCE_TARBALL"
fi
BUILD_DIR=".build-musl"
(test -d $BUILD_DIR && rm -rf $BUILD_DIR) || true
mkdir -p $BUILD_DIR
tar_extractor.py "$SOURCE_DIR/$SOURCE_TARBALL" -C $BUILD_DIR --strip 1
cd $BUILD_DIR
apply_patch musl-$MUSL_VERSION

for target in "${CROSS_TARGETS[@]}"; do
    if [[ $target == *"-musl"* ]]; then
        mkdir build-$target && cd build-$target
        CFLAGS="-O3" ../configure $CONFIGURE_ARGS --host=$target --target=$target --prefix=/ --disable-optimize --disable-wrapper
        if [ -n "$LIBC_STARTFILE_STAGE" ]; then
            echo "Install MUSL header and start files for target $target"
            make DESTDIR="$(target_install_prefix $target)" install-headers -j$(cpu_count)
        else
            echo "Install MUSL for target $target"
            make DESTDIR="$(target_install_prefix $target)" install -j$(cpu_count)
            # Convert /lib/ld-* symlinks to relative paths
            for f in `find "$(target_install_prefix $target)/lib" -type l -name "ld-musl*"`  
            do
                ln -sf libc.so "$f"
            done
        fi
        cd ..
    fi
done

