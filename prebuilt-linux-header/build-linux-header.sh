#!/bin/bash
set -e
cd "$(dirname "$0")"
PRE_PWD="$(pwd)"
cd ..
export __MSYS=1
source config
check_build_for_targets '-linux-' || exit 0

SOURCE_TARBALL=linux-$LINUX_KERNEL_VERSION.tar.xz
mkdir -p "$SOURCE_DIR"
if [ ! -f "$SOURCE_DIR/$SOURCE_TARBALL" ]; then
    curl -sSL "https://mirrors.ustc.edu.cn/kernel.org/linux/kernel/v${LINUX_KERNEL_VERSION%%.*}.x/$SOURCE_TARBALL" -o "$SOURCE_DIR/$SOURCE_TARBALL.tmp"
    mv "$SOURCE_DIR/$SOURCE_TARBALL.tmp" "$SOURCE_DIR/$SOURCE_TARBALL"
fi
BUILD_DIR=".build-linux-kernel"
(test -d $BUILD_DIR && rm -rf $BUILD_DIR) || true
mkdir -p $BUILD_DIR
tar_extractor.py "$SOURCE_DIR/$SOURCE_TARBALL" -C $BUILD_DIR --strip 1
cd $BUILD_DIR

for kernel_arch in riscv loongarch mips arm arm64 x86; do
    mkdir build-$kernel_arch && cd build-$kernel_arch
    make -C .. O="$(pwd)" ARCH=$kernel_arch INSTALL_HDR_PATH="$(pwd)/../linux-header-$kernel_arch" headers_install -j$(cpu_count)
    cd ..
    tar cvzf "$PRE_PWD/linux-header-${LINUX_KERNEL_VERSION}_$kernel_arch.tar.gz" -C linux-header-$kernel_arch ./include
done

