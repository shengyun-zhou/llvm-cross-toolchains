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
    if [[ $target == *"emscripten"* ]]; then
        # Emscripten: use compiler-rt built by emcc
        continue
    fi
    COMPILER_RT_CMAKE_FLAGS=""
    COMPILER_RT_CFLAGS=""
    COMPILER_RT_CXXFLAGS=""
    COMPILER_RT_LDFLAGS=""
    if [[ $target == *"apple"* ]]; then
        if [[ -n "$APPLE_BUILT" ]]; then
            continue
        else
            target="apple-darwin"
            COMPILER_RT_CMAKE_FLAGS="$COMPILER_RT_CMAKE_FLAGS -DCOMPILER_RT_ENABLE_MACCATALYST=ON"
            COMPILER_RT_LDFLAGS="$COMPILER_RT_LDFLAGS -D__FORCE_APPLE_DARWIN_TARGET"
        fi
    fi
    if [[ -z "$COMPILER_RT_FULL_BUILD" ]]; then        
        if [[ $target == *"msvc"* ]]; then
            # No need to build builtins for MSVC
            continue
        fi
    elif [[ $target == "wasm"* ]]; then
        continue
    fi
    mkdir build-$target && cd build-$target
    case $target in
    loongarch*)
        COMPILER_RT_CFLAGS="$COMPILER_RT_CFLAGS -fintegrated-as"
        ;;
    esac
    if [ -z "$COMPILER_RT_FULL_BUILD" ]; then
        COMPILER_RT_CMAKE_FLAGS="$COMPILER_RT_CMAKE_FLAGS -DCOMPILER_RT_EXCLUDE_ATOMIC_BUILTIN=OFF"
        if [[ $target == *"-mingw"* ]]; then
            COMPILER_RT_SRC_DIR="../lib/builtins"
        elif [[ $target == "wasm"* ]]; then
            COMPILER_RT_SRC_DIR="../lib/builtins"
            if [[ $target != *"wamr"* ]]; then
                COMPILER_RT_CMAKE_FLAGS="$COMPILER_RT_CMAKE_FLAGS -DCOMPILER_RT_BAREMETAL_BUILD=ON"
            fi
        else
            COMPILER_RT_CMAKE_FLAGS="$COMPILER_RT_CMAKE_FLAGS -DCOMPILER_RT_BUILD_LIBFUZZER=OFF -DCOMPILER_RT_BUILD_MEMPROF=OFF -DCOMPILER_RT_BUILD_PROFILE=OFF"
            COMPILER_RT_CMAKE_FLAGS="$COMPILER_RT_CMAKE_FLAGS -DCOMPILER_RT_BUILD_SANITIZERS=OFF -DCOMPILER_RT_BUILD_XRAY=OFF -DCOMPILER_RT_BUILD_ORC=OFF"
            COMPILER_RT_SRC_DIR=".."
            if [[ $target == *"linux"* ]]; then
                COMPILER_RT_LDFLAGS="$COMPILER_RT_LDFLAGS -nostdlib"
            elif [[ $target == *"apple"* ]]; then
                # Enable TVOS and WatchOS for builtins only now
                COMPILER_RT_CMAKE_FLAGS="$COMPILER_RT_CMAKE_FLAGS -DCOMPILER_RT_ENABLE_TVOS=ON -DCOMPILER_RT_ENABLE_WATCHOS=ON"
            fi
        fi
    else
        COMPILER_RT_SRC_DIR=".."
        COMPILER_RT_CMAKE_FLAGS="$COMPILER_RT_CMAKE_FLAGS -DCOMPILER_RT_BUILD_BUILTINS=OFF -DSANITIZER_CXX_ABI=libc++"
        if [[ $target == *"linux"* ]]; then
            COMPILER_RT_CXXFLAGS="$COMPILER_RT_CXXFLAGS -D__STDC_FORMAT_MACROS"
        fi
        if [[ $target == *"musl"* ]]; then
            COMPILER_RT_CMAKE_FLAGS="$COMPILER_RT_CMAKE_FLAGS -DCOMPILER_RT_BUILD_GWP_ASAN=OFF"
            # Santinizers for MUSL only support aarch64, x86_64 now.
            case $target in
            arm64*|aarch64*|x86_64*)
                ;;
            *)
                COMPILER_RT_CMAKE_FLAGS="$COMPILER_RT_CMAKE_FLAGS -DCOMPILER_RT_BUILD_SANITIZERS=OFF -DCOMPILER_RT_BUILD_XRAY=OFF -DCOMPILER_RT_BUILD_MEMPROF=OFF"
                ;;
            esac
        elif [[ $target == *"ohos"* ]]; then
            COMPILER_RT_CMAKE_FLAGS="$COMPILER_RT_CMAKE_FLAGS -DCOMPILER_RT_BUILD_GWP_ASAN=OFF"
        elif [[ $target == *"mingw"* || $target == *"windows"* || $target == *"bsd"* ]]; then
            # Santinizers on Windows/BSD only support x86 now
            case $target in
            i*86*|x86_64*)
                ;;
            *)
                COMPILER_RT_CMAKE_FLAGS="$COMPILER_RT_CMAKE_FLAGS -DCOMPILER_RT_BUILD_SANITIZERS=OFF -DCOMPILER_RT_BUILD_XRAY=OFF -DCOMPILER_RT_BUILD_MEMPROF=OFF"
                ;;
            esac
        fi
        
        if [[ $target != *"apple"* ]]; then
            if [[ $target != *"msvc"* && $target != *"freebsd"* ]]; then
                COMPILER_RT_CMAKE_FLAGS="$COMPILER_RT_CMAKE_FLAGS -DCOMPILER_RT_USE_BUILTINS_LIBRARY=TRUE"
            fi
        fi
    fi

    CFLAGS="$COMPILER_RT_CFLAGS" CXXFLAGS="$COMPILER_RT_CXXFLAGS" LDFLAGS="$COMPILER_RT_LDFLAGS" "$__CMAKE_WRAPPER" $target $COMPILER_RT_SRC_DIR \
        -DCMAKE_INSTALL_PREFIX="$COMPILER_RT_INSTALL_PREFIX" \
        -DCMAKE_C_COMPILER_WORKS=1 \
        -DCMAKE_CXX_COMPILER_WORKS=1 \
        -DCMAKE_C_COMPILER_TARGET=$target \
        -DCMAKE_CXX_COMPILER_TARGET=$target \
        -DCMAKE_ASM_COMPILER_TARGET=$target \
        -DCOMPILER_RT_DEFAULT_TARGET_ONLY=ON \
        -DCOMPILER_RT_USE_LIBCXX=OFF \
        -DLLVM_ENABLE_PER_TARGET_RUNTIME_DIR=ON \
        $COMPILER_RT_CMAKE_FLAGS

    cmake --build . --target install/strip -- -j$(cpu_count)
    if [[ $target == *"apple"* ]]; then
        APPLE_BUILT=1
    else
        # Clang >= 13.0.0 require directory name to be normalized target triple
        # Ref: https://github.com/llvm/llvm-project/commit/36430d44edba9063a08493c89864edf5f071d08c
        normalized_triple=$("$OUTPUT_DIR/bin/$target-clang" --print-target-triple)
        if [[ "$normalized_triple" != "$target" && -d "$COMPILER_RT_INSTALL_PREFIX/lib/$target" ]]; then
            ln -sfn $target "$COMPILER_RT_INSTALL_PREFIX/lib/$normalized_triple"
        fi
    fi
    if [[ -z "$COMPILER_RT_FULL_BUILD" && $target != *"apple"* && $target != *"msvc"* ]]; then
        # Put a fake empty libatomic.a in sysroot
        libatomic_path="$(target_install_prefix $target)/lib$(target_install_libdir_suffix $target)/libatomic.a"
        mkdir -p "$(dirname "$libatomic_path")"
        rm -f "$libatomic_path" || true
        "$OUTPUT_DIR/bin/llvm-ar" crs "$libatomic_path"
    fi
    cd ..
done

# Apple: fix shared lib ID
if [[ -n "$COMPILER_RT_FULL_BUILD" && -d "$COMPILER_RT_INSTALL_PREFIX/lib/darwin" ]]; then
    for dylib_file in "$COMPILER_RT_INSTALL_PREFIX/lib/darwin/"*.dylib; do
        "$OUTPUT_DIR/bin/llvm-install-name-tool" -id "@executable_path/$(basename "$dylib_file")" "$dylib_file"
    done
fi
