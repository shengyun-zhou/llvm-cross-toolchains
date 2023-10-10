#!/bin/bash
set -e
PRE_PWD="$(pwd)"
cd "$(dirname "$0")"
ROOT_DIR="$(pwd)"
source config
cd "$PRE_PWD"

TARGET=$1
CMAKE_ARGS=()
AR="$TARGET-ar${EXEC_SUFFIX}"
LLVM_TARGET_TRIPLE=$TARGET
TARGET_CFLAGS="$CFLAGS"
TARGET_CXXFLAGS="$CXXFLAGS"
case $TARGET in
    *linux*)
        CMAKE_ARGS+=(-DCMAKE_SYSTEM_NAME=Linux)
        TARGET_CFLAGS="$TARGET_CFLAGS -D_GNU_SOURCE"
        TARGET_CXXFLAGS="$TARGET_CXXFLAGS -D_GNU_SOURCE"
        ;;
    *mingw*|*windows*)
        CMAKE_ARGS+=(-DCMAKE_SYSTEM_NAME=Windows)
        if [[ $TARGET == *"msvc"* ]]; then
            AR="$TARGET-lib${EXEC_SUFFIX}"
            CMAKE_ARGS+=(
                -DCMAKE_LINKER="$OUTPUT_DIR/bin/$TARGET-ld${EXEC_SUFFIX}"
                -DCMAKE_MT="$OUTPUT_DIR/bin/$TARGET-mt${EXEC_SUFFIX}"
            )
        fi
        ;;
    *apple*)
        CMAKE_ARGS+=(-DCMAKE_SYSTEM_NAME=Darwin -DCMAKE_LIBTOOL="$OUTPUT_DIR/bin/llvm-libtool-darwin${EXEC_SUFFIX}")
        CMAKE_ARGS+=(-DCMAKE_LIPO="$OUTPUT_DIR/bin/llvm-lipo${EXEC_SUFFIX}" -DCMAKE_LINKER="$OUTPUT_DIR/bin/$TARGET-ld${EXEC_SUFFIX}")
        ;;
    *freebsd*)
        CMAKE_ARGS+=(-DCMAKE_SYSTEM_NAME=FreeBSD)
        ;;
    *wasi*)
        CMAKE_ARGS+=(-DCMAKE_SYSTEM_NAME=WASI -DCMAKE_MODULE_PATH="$ROOT_DIR/cmake")
        ;;
    *)
        echo "Unrecognized target $TARGET for CMake wrapper"
        exit 1
        ;;    
esac
if [[ $TARGET == *"ohos"* ]]; then
    CMAKE_ARGS+=(-DOHOS=1)
fi
shift
CFLAGS="$TARGET_CFLAGS" CXXFLAGS="$TARGET_CXXFLAGS" cmake -Wno-dev -G Ninja -DCMAKE_BUILD_TYPE=Release "${CMAKE_ARGS[@]}" \
    -DCMAKE_C_COMPILER="$OUTPUT_DIR/bin/$TARGET-clang${EXEC_SUFFIX}" \
    -DCMAKE_CXX_COMPILER="$OUTPUT_DIR/bin/$TARGET-clang++${EXEC_SUFFIX}"  \
    -DCMAKE_AR="$OUTPUT_DIR/bin/$AR" \
    -DCMAKE_RANLIB="$OUTPUT_DIR/bin/$TARGET-ranlib${EXEC_SUFFIX}" \
    -DCMAKE_STRIP="$OUTPUT_DIR/bin/$TARGET-strip${EXEC_SUFFIX}" \
    -DCMAKE_BUILD_WITH_INSTALL_RPATH=TRUE \
    -DLLVM_DEFAULT_TARGET_TRIPLE=$LLVM_TARGET_TRIPLE \
    "$@"
