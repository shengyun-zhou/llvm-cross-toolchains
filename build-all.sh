#!/bin/bash
set -e
cd "$(dirname "$0")"
source config

./build-llvm.sh
./install-wrapper.sh
./install-prebuilt-stuff.sh
./build-all-native-tools.sh
LIBC_STARTFILE_STAGE=1 ./build-musl.sh
LIBC_STARTFILE_STAGE=1 ./build-mingw.sh
./build-emscripten.sh
./build-wasi-libc.sh
./build-compiler-rt.sh
./build-musl.sh
./build-mingw.sh
./build-libunwind.sh
./build-wasi-libunwind.sh
./build-libcxx.sh
COMPILER_RT_FULL_BUILD=1 ./build-compiler-rt.sh
