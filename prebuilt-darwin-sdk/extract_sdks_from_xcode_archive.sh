#!/bin/bash
set -e
cd "$(dirname "$0")"
PRE_CWD="$(pwd)"
cd .. && source config && cd "$PRE_CWD"

SDKS=(
    "MacOSX" 
    "iPhoneOS"
    "iPhoneSimulator"
    "AppleTVOS"
    "AppleTVSimulator"
    "WatchOS"
    "WatchSimulator"
)

rm -rf .temp_sdk_dir || true
mkdir .temp_sdk_dir
cd .temp_sdk_dir
echo "Extracting $1..."
../extract_xcode.py -f "$1" | cpio -i

for sdk_prefix in "${SDKS[@]}"; do
    sdk_ver="$(PlistBuddy Xcode.app/Contents/Developer/Platforms/$sdk_prefix.platform/Info.plist -c "Print Version")"
    sdk_path="Xcode.app/Contents/Developer/Platforms/$sdk_prefix.platform/Developer/SDKs/$sdk_prefix.sdk"
    tar_file="${sdk_prefix}${sdk_ver}.sdk.tar.xz"
    echo "Creating $tar_file..."
    tar cJf "../$tar_file" -C "$sdk_path" ./
done

echo "Cleaning up..."
cd .. && rm -rf .temp_sdk_dir
