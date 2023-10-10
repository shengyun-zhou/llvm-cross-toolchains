#!/bin/bash
set -e
cd "$(dirname "$0")"
PRE_PWD="$(pwd)"
cd ..
source config
cd "$PRE_PWD"
echo "OHOS_SDK_HOME: $OHOS_SDK_HOME"

OHOS_SYSROOT="$OHOS_SDK_HOME/$OHOS_API/native/sysroot"
for target in "${CROSS_TARGETS[@]}"; do
    if [[ $target == *"ohos"* ]]; then
        case $target in
        aarch64*|arm64*)
            OHOS_ARCH_LIB_DIR=usr/lib/aarch64-linux-ohos
            ;;
        arm*)
            OHOS_ARCH_LIB_DIR=usr/lib/arm-linux-ohos
            ;;
        x86_64*)
            OHOS_ARCH_LIB_DIR=usr/lib/x86_64-linux-ohos
            ;;
        esac
        tar cvzf ohos-libs_${target}.tar.gz -C "$OHOS_SYSROOT/$OHOS_ARCH_LIB_DIR" .
    fi
done
tar cvzf ohos-headers.tar.gz -C "$OHOS_SYSROOT/usr/include" .
