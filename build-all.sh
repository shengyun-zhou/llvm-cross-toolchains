#!/bin/bash
set -e
cd "$(dirname "$0")"
source config

bash ./build-llvm.sh
bash ./install-wrapper.sh
bash ./install-prebuilt-stuff.sh
bash ./build-gnu-binutils.sh
bash ./build-cygwin-gcc.sh
LIBC_STARTFILE_STAGE=1 bash ./build-musl.sh
LIBC_STARTFILE_STAGE=1 bash ./build-mingw.sh
bash ./build-compiler-rt.sh
bash ./build-musl.sh
bash ./build-mingw-tools.sh
bash ./build-mingw.sh
bash ./build-libunwind.sh
bash ./build-libcxx.sh
COMPILER_RT_FULL_BUILD=1 bash ./build-compiler-rt.sh
