#!/bin/bash
# Copy prebuilt sysroot and compiler_rt from prebuilt LLVM cross toolchains
set -e
cd "$(dirname "$0")"
source config

declare -A APPLE_INSTALLED_SDK
mkdir -p "$OUTPUT_DIR/lib/clang/$LLVM_MAJOR_VERSION/lib"
unset MSVC_SDK_INSTALLED
unset EMSCRIPTEN_INSTALLED
for target in "${CROSS_TARGETS[@]}"; do
    if [[ $target == *"apple"* ]]; then
        DARWIN_SDK_NAME=""
        case "$target" in
        *macosx*|*ios*-macabi*) DARWIN_SDK_NAME=MacOSX ;;
        *ios*-simulator*) DARWIN_SDK_NAME=iPhoneSimulator ;;
        *ios*) DARWIN_SDK_NAME=iPhoneOS ;;
        *tvos*-simulator*) DARWIN_SDK_NAME=AppleTVSimulator ;;
        *tvos*) DARWIN_SDK_NAME=AppleTVOS ;;
        *watchos*-simulator*) DARWIN_SDK_NAME=WatchSimulator ;;
        *watchos*) DARWIN_SDK_NAME=WatchOS ;;    
        esac

        if [[ -z "${APPLE_INSTALLED_SDK[$DARWIN_SDK_NAME]}" ]]; then
            cp -r "$LLVM_CROSS_TOOLCHAINS_ROOT/$DARWIN_SDK_NAME-SDK" "$OUTPUT_DIR"
            APPLE_INSTALLED_SDK[$DARWIN_SDK_NAME]=1
        fi
        ln -sfn "$DARWIN_SDK_NAME-SDK" "$OUTPUT_DIR/$target"
    elif [[ $target == *"msvc"* ]]; then
        if [[ -z "$MSVC_SDK_INSTALLED" ]]; then
            cp -r "$LLVM_CROSS_TOOLCHAINS_ROOT/MSVC-SDK" "$OUTPUT_DIR"
            MSVC_SDK_INSTALLED=1
        fi
        if [[ -d "$LLVM_CROSS_TOOLCHAINS_ROOT/$target" ]]; then
            cp -r "$LLVM_CROSS_TOOLCHAINS_ROOT/$target" "$OUTPUT_DIR"
        fi
    elif [[ $target == *"emscripten"* ]]; then
        if [[ -z "$EMSCRIPTEN_INSTALLED" ]]; then
            cp -r "$LLVM_CROSS_TOOLCHAINS_ROOT/emscripten" "$OUTPUT_DIR/emscripten" 
            EMSCRIPTEN_INSTALLED=1
        fi
    else
        cp -r "$LLVM_CROSS_TOOLCHAINS_ROOT/$target" "$OUTPUT_DIR"
    fi
done

cp -P -r "$LLVM_CROSS_TOOLCHAINS_ROOT/lib/clang/$LLVM_MAJOR_VERSION/lib" "$OUTPUT_DIR/lib/clang/$LLVM_MAJOR_VERSION"
