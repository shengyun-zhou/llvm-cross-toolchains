#!/bin/bash
set -e
cd "$(dirname "$0")"
source config

./build-gnu-binutils.sh
./build-mingw-tools.sh
./build-binaryen.sh
./build-wabt.sh
./build-wamrc.sh
