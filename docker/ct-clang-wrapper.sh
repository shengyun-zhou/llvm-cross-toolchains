#!/bin/bash
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
BASENAME="$(basename "$0")"
TARGET="${BASENAME%-*}"
EXE="${BASENAME##*-}"

CLANG_ARGS=(-Qunused-arguments -target $TARGET --sysroot "$DIR/../$TARGET/sysroot" --gcc-toolchain="$DIR/.." -fuse-ld=lld -static-libgcc)

if [[ $@ =~ (^|[[:space:]])-print-multiarch($|[[:space:]]) ]]; then
    # Hack -print-multiarch for empty output
    echo ""
    exit 0
fi

if [[ $EXE == "clang++" ]]; then
    EXE=clang++
else
    EXE=clang
fi

$EXE "${CLANG_ARGS[@]}" "$@"
