#!/bin/bash

function apply_patch {
    if [ -d "$PATCH_DIR/$1" ]; then
        for patchfile in "$PATCH_DIR/$1/"*.patch; do
            patch -p1 < "$patchfile"
        done
    fi
}

function check_build_for_targets {
    for target in "${CROSS_TARGETS[@]}"; do
        if [[ $target == *"$1"* ]]; then
            return 0
        fi
    done
    return 1
}

function cpu_count {
    if [[ $BUILD_HOST == "Darwin" ]]; then
        NCPU="$(sysctl -n hw.logicalcpu)"
    else
        NCPU="$(nproc)"
    fi
    if [ -n "$SAVE_CPU" ]; then
        NCPU=`expr $NCPU / 2`
    fi
    echo "$NCPU"
}

function target_install_prefix {
    if [[ "$1" == *"mingw"* || "$1" == *"windows"* ]]; then
        echo "$OUTPUT_DIR/$1"
    else
        echo "$OUTPUT_DIR/$1/usr"
    fi
}
