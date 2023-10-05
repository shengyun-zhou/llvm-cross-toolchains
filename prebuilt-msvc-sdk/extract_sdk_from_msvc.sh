#!/bin/bash
set -e
cd "$(dirname "$0")"
PRE_CWD="$(pwd)"
cd .. && source config
cd "$PRE_CWD"

SED=sed
if [[ $BUILD_HOST == "Darwin" ]]; then
    SED=gsed
fi

# Remove the ending \ in original WindowsSDKVersion
WindowsSDKVersion=$(basename "$WindowsSDKVersion")

rm -rf .temp_sdk_dir || true
mkdir -p .temp_sdk_dir/winsdk/Include .temp_sdk_dir/winsdk/Lib
cp -r "$WindowsSdkDir/Include/$WindowsSDKVersion" .temp_sdk_dir/winsdk/Include
cp -r "$WindowsSdkDir/Lib/$WindowsSDKVersion" .temp_sdk_dir/winsdk/Lib

mkdir -p .temp_sdk_dir/vc
cp -r "$VCToolsInstallDir/include" "$VCToolsInstallDir/lib" .temp_sdk_dir/vc
# Rename all files to its lowercase
for SRC in `find .temp_sdk_dir -depth -type f`
do
    DST=`dirname "${SRC}"`/`basename "${SRC}" | tr '[A-Z]' '[a-z]'`
    if [ "${SRC}" != "${DST}" ]; then
        mv -T "${SRC}" "${DST}"
    fi
done
# Rename #include <file> to its lowercase
find .temp_sdk_dir/vc/include .temp_sdk_dir/winsdk/Include -type f -exec $SED -E 's/^#include (["<].+)/#include \L\1/g' -i {} \;
tar cvzf WindowsSDK-$WindowsSDKVersion.tar.gz -C .temp_sdk_dir/winsdk ./
tar cvzf VC-$VCToolsVersion.tar.gz --exclude=./lib/onecore* --exclude=./lib/*/clang_rt* -C .temp_sdk_dir/vc ./
rm -rf .temp_sdk_dir
