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
./build-wamr-ext-libs.sh
./build-compiler-rt.sh
./build-musl.sh
./build-mingw.sh
./build-libunwind.sh
./build-wasi-libunwind.sh
./build-mingw-libssp.sh
./build-libcxx.sh
WAMR_EXT_ALL_LIBS=1 ./build-wamr-ext-libs.sh
COMPILER_RT_FULL_BUILD=1 ./build-compiler-rt.sh
