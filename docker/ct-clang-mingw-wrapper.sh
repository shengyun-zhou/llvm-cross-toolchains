#!/bin/bash
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
BASENAME="$(basename "$0")"
TARGET="${BASENAME%-*}"
EXE="${BASENAME##*-}"
GCC_VERSION=11.2.0

CLANG_ARGS=(-Qunused-arguments -target $TARGET --sysroot "$DIR/../$TARGET/sysroot/mingw" 
    -L "$DIR/../lib/gcc/$TARGET/$GCC_VERSION" -L "$DIR/../$TARGET/sysroot/lib" -static-libgcc)

if [[ $EXE == "clang++" ]]; then
    EXE=clang++
else
    EXE=clang
fi

$EXE "${CLANG_ARGS[@]}" "$@" -Wno-unused-but-set-variable
