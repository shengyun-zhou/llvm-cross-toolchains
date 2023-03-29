#!/bin/bash
set -e
cd "$(dirname "$0")"
source config
for target in "${CROSS_TARGETS[@]}"; do
    if [[ $target == *"apple"* ]]; then
        CROSS_TARGETS+=('apple-darwin')     # Special internal cross target for compiling compiler-rt
        break
    fi
done

cd wrapper && go_build -o "$OUTPUT_DIR/bin/toolchain-wrapper${CROSS_EXEC_SUFFIX}"
cd ..
cp -r cmake "$OUTPUT_DIR"

PRE_PWD="$(pwd)"
cd "$OUTPUT_DIR/bin"
for target in "${CROSS_TARGETS[@]}"; do
    for exec in clang clang++ gcc g++ cc c++ as cpp; do
        ln -sf toolchain-wrapper${CROSS_EXEC_SUFFIX} $target-$exec${CROSS_EXEC_SUFFIX}
    done
    for exec in addr2line ar ranlib nm objcopy strings strip objdump readelf size; do
        ln -sf llvm-$exec${CROSS_EXEC_SUFFIX} $target-$exec${CROSS_EXEC_SUFFIX}
    done
    ln -sf toolchain-wrapper${CROSS_EXEC_SUFFIX} $target-ld${CROSS_EXEC_SUFFIX}
    ln -sf llvm-cxxfilt${CROSS_EXEC_SUFFIX} $target-c++filt${CROSS_EXEC_SUFFIX}
    if [[ $target == *"-mingw"* || $target == *"windows"* ]]; then
        ln -sf llvm-dlltool${CROSS_EXEC_SUFFIX} $target-dlltool${CROSS_EXEC_SUFFIX}
        ln -sf llvm-windres${CROSS_EXEC_SUFFIX} $target-windres${CROSS_EXEC_SUFFIX}
        if [[ $target == *"msvc"* ]]; then
            rm -f $target-cpp${CROSS_EXEC_SUFFIX}
            ln -sf llvm-rc${CROSS_EXEC_SUFFIX} $target-rc${CROSS_EXEC_SUFFIX}
            ln -sf llvm-lib${CROSS_EXEC_SUFFIX} $target-lib${CROSS_EXEC_SUFFIX}
            ln -sf llvm-mt${CROSS_EXEC_SUFFIX} $target-mt${CROSS_EXEC_SUFFIX}
            ln -sf toolchain-wrapper${CROSS_EXEC_SUFFIX} $target-cl${CROSS_EXEC_SUFFIX}
            ln -sf toolchain-wrapper${CROSS_EXEC_SUFFIX} $target-link${CROSS_EXEC_SUFFIX}
        fi
    fi
done

cd "$PRE_PWD"
# Install prebuilt cctools and their wrapper
unset CCTOOLS_INSTALLED
for target in "${CROSS_TARGETS[@]}"; do
    if [[ $target == *"apple-"* ]]; then
        if [[ -z "$CCTOOLS_INSTALLED" ]]; then
            tar_extractor.py prebuilt-cctools/cctools.tar.gz -C "$OUTPUT_DIR"
            for binfile in "$OUTPUT_DIR/cctools-bin/"*; do
                cp "$binfile" "$OUTPUT_DIR/bin"
            done
            CCTOOLS_INSTALLED=1
        fi

        for binfile in "$OUTPUT_DIR/cctools-bin/"*; do
            target_binfile="$OUTPUT_DIR/bin/$target-${binfile##*-}"
            ln -sf "toolchain-wrapper${CROSS_EXEC_SUFFIX}" "${target_binfile}${CROSS_EXEC_SUFFIX}"
        done
    fi
done
if [[ $CROSS_HOST == "Windows" && -d "$OUTPUT_DIR/lib-llvm" ]]; then
    # Copy LLVM runtime library for cctools running in WSL
    cp -r -P "$OUTPUT_DIR/lib-llvm/"* "$OUTPUT_DIR/lib/"
fi
(test -d "$OUTPUT_DIR/cctools-bin" && rm -rf "$OUTPUT_DIR/cctools-bin") || true
(test -d "$OUTPUT_DIR/lib-llvm" && rm -rf "$OUTPUT_DIR/lib-llvm") || true
