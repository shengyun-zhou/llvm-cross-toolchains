#!/bin/bash
set -e
cd "$(dirname "$0")"
source config
export PATH="$OUTPUT_DIR/bin:$PATH"

SOURCE_TARBALL=llvm-project-$LLVM_VERSION.src.tar.xz
BUILD_DIR=".build-compiler-rt"
(test -d $BUILD_DIR && rm -rf $BUILD_DIR) || true
mkdir -p $BUILD_DIR
tar_extractor.py "$SOURCE_DIR/$SOURCE_TARBALL" -C $BUILD_DIR --strip 1
cd $BUILD_DIR
apply_patch llvm-$LLVM_VERSION
cd compiler-rt
# Hack for Apple build
if [[ $BUILD_HOST != "Darwin" ]]; then
    sed -i -e "s/\/usr\/libexec\/PlistBuddy/PlistBuddy${SCRIPT_SUFFIX}/g" cmake/builtin-config-ix.cmake || true
    sed -i -e "s/COMMAND xcrun/COMMAND xcrun${SCRIPT_SUFFIX}/g" cmake/base-config-ix.cmake || true
    sed -i -e "s/COMMAND xcrun/COMMAND xcrun${SCRIPT_SUFFIX}/g" cmake/Modules/CompilerRTDarwinUtils.cmake || true
    sed -i -e "s/ERROR_FILE/#ERROR_FILE/g" cmake/Modules/CompilerRTDarwinUtils.cmake || true
    sed -i -e "s/COMMAND codesign/COMMAND codesign${SCRIPT_SUFFIX}/g" cmake/Modules/AddCompilerRT.cmake || true
fi

unset APPLE_BUILT
COMPILER_RT_INSTALL_PREFIX="$("$OUTPUT_DIR/bin/clang" --print-resource-dir)"
for target in "${CROSS_TARGETS[@]}"; do
    if [[ $target == *"apple"* ]]; then
        if [[ -n "$APPLE_BUILT" ]]; then
            continue
        else
            target="apple-darwin"
        fi
    fi
    if [[ -n "$COMPILER_RT_FULL_BUILD" ]]; then
        if [[ $target == *"musl"* ]]; then
            # Santinizers cannot be built on MUSL now
            continue
        elif [[ $target == *"mingw"* || $target == *"windows"* ]]; then
            # Santinizers on Windows only support x86 now
            case $target in
            i*86*|x86_64*)
                ;;
            *)
                continue
                ;;
            esac
        fi
    elif [[ $target == *"msvc"* ]]; then
        # No need to build builtins for MSVC
        continue
    fi
    mkdir build-$target && cd build-$target
    COMPILER_RT_COMPILER_TARGET=$target
    COMPILER_RT_CMAKE_FLAGS=""
    COMPILER_RT_CFLAGS=""
    case $target in
    aarch64*|arm64*)
        ;;
    arm*)
        if [[ $target == *"mingw"* ]]; then
            COMPILER_RT_COMPILER_TARGET="armv7-w64-mingw32"
        fi
        ;;
    esac
    if [ -z "$COMPILER_RT_FULL_BUILD" ]; then
        if [[ $target == *"-mingw"* ]]; then
            COMPILER_RT_SRC_DIR="../lib/builtins"
        else
            COMPILER_RT_CMAKE_FLAGS="$COMPILER_RT_CMAKE_FLAGS -DCOMPILER_RT_BUILD_LIBFUZZER=OFF -DCOMPILER_RT_BUILD_MEMPROF=OFF -DCOMPILER_RT_BUILD_PROFILE=OFF"
            COMPILER_RT_CMAKE_FLAGS="$COMPILER_RT_CMAKE_FLAGS -DCOMPILER_RT_BUILD_SANITIZERS=OFF -DCOMPILER_RT_BUILD_XRAY=OFF -DCOMPILER_RT_BUILD_ORC=OFF"
            COMPILER_RT_SRC_DIR=".."
            if [[ $target == *"linux"* ]]; then
                COMPILER_RT_CFLAGS="$COMPILER_RT_CFLAGS -nostdlib"
            elif [[ $target == *"apple"* ]]; then
                # Enable TVOS and WatchOS for builtins only now
                COMPILER_RT_CMAKE_FLAGS="$COMPILER_RT_CMAKE_FLAGS -DCOMPILER_RT_ENABLE_TVOS=ON -DCOMPILER_RT_ENABLE_WATCHOS=ON"
            fi
        fi
    else
        COMPILER_RT_SRC_DIR=".."
        COMPILER_RT_CMAKE_FLAGS="$COMPILER_RT_CMAKE_FLAGS -DCOMPILER_RT_BUILD_BUILTINS=OFF -DSANITIZER_CXX_ABI=libc++"
        if [[ $target != *"apple"* ]]; then
            if [[ $target != *"msvc"* ]]; then
                COMPILER_RT_CMAKE_FLAGS="$COMPILER_RT_CMAKE_FLAGS -DCOMPILER_RT_USE_BUILTINS_LIBRARY=TRUE"
            fi
            if [[ $target != $COMPILER_RT_COMPILER_TARGET ]]; then
                # symlink target dir temporarily
                mkdir -p "$COMPILER_RT_INSTALL_PREFIX/lib/$target"
                ln -sfn $target "$COMPILER_RT_INSTALL_PREFIX/lib/$COMPILER_RT_COMPILER_TARGET"
                ln -sfn $target "$COMPILER_RT_INSTALL_PREFIX/lib/$("$OUTPUT_DIR/bin/$target-clang" --target=$COMPILER_RT_COMPILER_TARGET --print-target-triple)"
            fi
        fi
    fi

    CFLAGS="$COMPILER_RT_CFLAGS" "$__CMAKE_WRAPPER" $target $COMPILER_RT_SRC_DIR \
        -DCMAKE_INSTALL_PREFIX="$COMPILER_RT_INSTALL_PREFIX" \
        -DCMAKE_C_COMPILER_WORKS=1 \
        -DCMAKE_CXX_COMPILER_WORKS=1 \
        -DCMAKE_C_COMPILER_TARGET=$COMPILER_RT_COMPILER_TARGET \
        -DCMAKE_CXX_COMPILER_TARGET=$COMPILER_RT_COMPILER_TARGET \
        -DCMAKE_ASM_COMPILER_TARGET=$COMPILER_RT_COMPILER_TARGET \
        -DCOMPILER_RT_DEFAULT_TARGET_ONLY=ON \
        -DLLVM_ENABLE_PER_TARGET_RUNTIME_DIR=ON \
        $COMPILER_RT_CMAKE_FLAGS

    cmake --build . --target install/strip -- -j$(cpu_count)
    if [[ $target == *"apple"* ]]; then
        APPLE_BUILT=1
    else
        # Clang >= 13.0.0 require directory name to be normalized target triple
        # Ref: https://github.com/llvm/llvm-project/commit/36430d44edba9063a08493c89864edf5f071d08c
        if [[ $target != $COMPILER_RT_COMPILER_TARGET ]]; then
            if [ -n "$COMPILER_RT_FULL_BUILD" ]; then
                rm -f "$COMPILER_RT_INSTALL_PREFIX/lib/$COMPILER_RT_COMPILER_TARGET" \
                      "$COMPILER_RT_INSTALL_PREFIX/lib/$("$OUTPUT_DIR/bin/$target-clang" --target=$COMPILER_RT_COMPILER_TARGET --print-target-triple)"
            else
                # Rename target dir
                rm -rf "$COMPILER_RT_INSTALL_PREFIX/lib/$target" || true
                mv "$COMPILER_RT_INSTALL_PREFIX/lib/$COMPILER_RT_COMPILER_TARGET" "$COMPILER_RT_INSTALL_PREFIX/lib/$target"
            fi
        fi
        normalized_triple=$("$OUTPUT_DIR/bin/$target-clang" --print-target-triple)
        if [[ "$normalized_triple" != "$target" ]]; then
            ln -sfn $target "$COMPILER_RT_INSTALL_PREFIX/lib/$normalized_triple"
        fi
    fi
    cd ..
done

# Apple: fix shared lib ID
if [[ -n "$COMPILER_RT_FULL_BUILD" && -d "$OUTPUT_DIR/lib/clang/$LLVM_VERSION/lib/darwin" ]]; then
    for dylib_file in "$OUTPUT_DIR/lib/clang/$LLVM_VERSION/lib/darwin/"*.dylib; do
        "$OUTPUT_DIR/bin/llvm-install-name-tool" -id "@executable_path/$(basename "$dylib_file")" "$dylib_file"
    done
fi
