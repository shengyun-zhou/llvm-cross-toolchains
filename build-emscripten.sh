#!/bin/bash
set -e
cd "$(dirname "$0")"
source config
check_build_for_targets '-emscripten' || exit 0

export PATH="$OUTPUT_DIR/bin:$PATH"
SOURCE_TARBALL=emscripten-$EMSCRIPTEN_VERSION.tar.gz
mkdir -p "$SOURCE_DIR"
if [ ! -f "$SOURCE_DIR/$SOURCE_TARBALL" ]; then
    curl -sSL "https://${GITHUB_MIRROR_DOMAIN:-github.com}/emscripten-core/emscripten/archive/refs/tags/$EMSCRIPTEN_VERSION.tar.gz" -o "$SOURCE_DIR/$SOURCE_TARBALL.tmp"
    mv "$SOURCE_DIR/$SOURCE_TARBALL.tmp" "$SOURCE_DIR/$SOURCE_TARBALL"
fi
BUILD_DIR=".build-emscripten"
(test -d $BUILD_DIR && rm -rf $BUILD_DIR) || true
mkdir -p $BUILD_DIR
tar_extractor.py "$SOURCE_DIR/$SOURCE_TARBALL" -C $BUILD_DIR --strip 1
cd $BUILD_DIR && apply_patch emscripten-$EMSCRIPTEN_VERSION

touch _emscripten_config_stub.py
cp ../build-tools/emscripten_env .emscripten
NODE_ENV=production npm install --no-optional

# Clean
rm -rf tests || true
rm -rf site || true
rm -rf "$OUTPUT_DIR/emscripten" || true

cd .. && cp -r $BUILD_DIR "$OUTPUT_DIR/emscripten"
