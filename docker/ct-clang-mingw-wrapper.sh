#!/bin/bash
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
BASENAME="$(basename "$0")"
TARGET="${BASENAME%-*}"
EXE="${BASENAME##*-}"

CLANG_ARGS=(-Qunused-arguments -target $TARGET --sysroot "$DIR/../$TARGET" -rtlib=compiler-rt -unwindlib=libunwind -stdlib=libc++ -fuse-ld=ld)

if [[ $EXE == "clang++" ]]; then
    EXE=/usr/bin/clang++
else
    if [[ $EXE == "cpp" ]]; then
        CLANG_ARGS+=(--driver-mode=cpp)
    fi
    EXE=/usr/bin/clang
fi

$EXE "${CLANG_ARGS[@]}" "$@" -Wno-unused-but-set-variable
