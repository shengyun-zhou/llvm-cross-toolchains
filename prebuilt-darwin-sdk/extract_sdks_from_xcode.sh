#!/bin/bash
set -e
cd "$(dirname "$0")"

SDKS=(
    "MacOSX" 
    "iPhoneOS"
    "iPhoneSimulator"
    "AppleTVOS"
    "AppleTVSimulator"
    "WatchOS"
    "WatchSimulator"
)

for sdk_prefix in "${SDKS[@]}"; do
    sdk_name="$(echo "$sdk_prefix" | tr '[:upper:]' '[:lower:]')"
    sdk_ver="$(xcrun --sdk $sdk_name --show-sdk-version)"
    sdk_path="$(xcrun --sdk $sdk_name --show-sdk-path)"
    tar_file="${sdk_prefix}${sdk_ver}.sdk.tar.xz"
    echo "Creating $tar_file"
    gtar cvJf "$tar_file" --hard-dereference -C "$sdk_path" ./
done

