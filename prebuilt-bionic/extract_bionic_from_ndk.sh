#!/bin/bash
set -e
cd "$(dirname "$0")"
PRE_PWD="$(pwd)"
cd ..
source config
cd "$PRE_PWD"
echo "ANDROID_NDK_HOME: $ANDROID_NDK_HOME"

NDK_HOST_TAG=$(ls "$ANDROID_NDK_HOME/toolchains/llvm/prebuilt")
NDK_SYSROOT="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$NDK_HOST_TAG/sysroot"
for target in "${CROSS_TARGETS[@]}"; do
    if [[ $target == *"android"* ]]; then
        ANDROID_API=$(echo $target | grep -Eo '[0-9]+$')
        ANDROID_ARCH_LIB_DIR=""
        case $target in
        aarch64*|arm64*)
            ANDROID_ARCH_LIB_DIR=usr/lib/aarch64-linux-android
            ;;
        arm*)
            ANDROID_ARCH_LIB_DIR=usr/lib/arm-linux-androideabi
            ;;
        i*86*)
            ANDROID_ARCH_LIB_DIR=usr/lib/i686-linux-android
            ;;
        x86_64*)
            ANDROID_ARCH_LIB_DIR=usr/lib/x86_64-linux-android
            ;;
        esac
        tar cvzf bionic-libs_${target}.tar.gz --exclude=./libcompiler_rt* --exclude=./libclang* --exclude=./libc++* --exclude=./libstdc++* --exclude=./libunwind* -C "$NDK_SYSROOT/$ANDROID_ARCH_LIB_DIR/$ANDROID_API" .
    fi
done
tar cvzf bionic-headers.tar.gz --exclude=./c++ -C "$NDK_SYSROOT/usr/include" .
