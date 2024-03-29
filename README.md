## LLVM Cross Toolchain

A cross toolchain collection based on LLVM with multi architecture and platform support.

Supported target platforms:

+ Linux: musl-libc, glibc

+ Android

+ Windows: MinGW, MSVC(Experiment)

+ Darwin: MacOSX, Mac-Catalyst, iOS, tvOS, watchOS

+ BSD: FreeBSD

+ WebAssembly(WASM): Emscripten, [WAMR(with custom extensions)](https://github.com/shengyun-zhou/wamr-wasm-libs)

The toolchain itself works on Linux, Windows and MacOSX now.

### Build

#### 1. Prerequisite tools and libs

+ GCC or Clang that supports C++17 and later

+ CMake >= 3.15

+ Ninja

  It can be installed via `pip`:

  ```sh
  pip install ninja
  ```

+ Python 3 >= 3.7

  > Python >= 3.8 is required on Windows to support unelevated symlinks with developer mode

+ Golang(latest version recommended)

+ Some development libs:

| Lib     | CentOS        | Ubuntu/Debian |
| ------- | ------------- | ------------- |
| libz    | zlib-devel    | zlib1g-dev    |
| liblzma | xz-devel      | liblzma-dev   |
| libxml2 | libxml2-devel | libxml2-dev   |

+ Windows host: 

    + MSYS2
    
    > NOTE: To build in MSYS2, you can install the following packages with `pacman`: 
    >
    > ```
    > curl rsync make patch
    > mingw-w64-x86_64-gcc mingw-w64-x86_64-cmake mingw-w64-x86_64-ninja mingw-w64-x86_64-python3 mingw-w64-x86_64-zlib mingw-w64-x86_64-xz mingw-w64-x86_64-libxml2 mingw-w64-x86_64-polly
    > ```
    
    + Windows subsystem for Linux(WSL) with any Linux distribution(Optional)

#### 2. Configure project

The file `version` contains the versions of some important toolchain components, such as glibc, musl-libc and so on.

The array variable `CROSS_TARGETS` in the file `cross-targets` defines all cross target triples to be built.

You can change `version` and `cross-targets` based on your need.

#### 3. Prepare stuff

##### (1) Linux kernel header

> NOTE for MacOSX host: Linux kernel header must be built on Linux environment, it's recommended to build in Docker Linux image.

```sh
prebuilt-linux-header/build-linux-header.sh
```

##### (2) Linux glibc

> NOTE: glibc must be built in glibc based Linux environment(eg. CentOS, Debian, Ubuntu).

Prerequisite development libs:

| Lib     | CentOS       | Ubuntu/Debian   |
| ------- | ------------ | --------------- |
| libgmp  | gmp-devel    | libgmp-dev      |
| libmpfr | mpfr-devel   | libmpfr-dev     |
| libmpc  | libmpc-devel | libmpc-dev      |


```sh
# Build glibc from source, it will take a long time
prebuilt-glibc/build-glibc.sh
```

##### (3) Android Bionic libc

Prerequisite: Android NDK >= r21e

```sh
# Set the installation path of Android NDK
export ANDROID_NDK_HOME=/path/to/android-ndk
# Extract Bionic headers and libs from NDK
prebuilt-bionic/extract_bionic_from_ndk.sh
```

##### (4) Darwin SDKs

**Method 1: (recommended)extract SDKs from `Xcode.xip` package**

1. Download `Xcode.xip` from [official Apple Developer website](https://developer.apple.com/download) 

2. Execute tool:

```sh
./prebuilt-darwin-sdk/extract_sdks_from_xcode_archive.sh /path/to/Xcode.xip
```

3. Check and modify values of `MACOSX_VERSION`, `IOS_VERSION`, `APPLE_TVOS_VERSION`, `APPLE_WATCHOS_VERSION` in file `version` to match those of extracted SDKs in dir `prebuilt-darwin-sdk`.

**Method 2: (MacOSX host only)extract SDKs from installed Xcode**

1. Install gnu-tar, it can be installed via homebrew:

   ```sh
   brew install gnu-tar
   ```

   Check if command `gtar` is available.

2. Execute tool:

   ```sh
   prebuilt-darwin-sdk/extract_sdks_from_xcode.sh
   ```

3. Check and modify values of `MACOSX_VERSION`, `IOS_VERSION`, `APPLE_TVOS_VERSION`, `APPLE_WATCHOS_VERSION` in file `version` to match those of extracted SDKs in dir `prebuilt-darwin-sdk`.

##### (5) Apple cctools

> NOTE for Windows host: cctools must be built in WSL.

Prerequisite:

+ clang >= 4
+ development libs:

| Lib     | CentOS       | Ubuntu/Debian   |
| ------- | ------------ | --------------- |
| llvm    | llvm-devel   | llvm-dev        |
| llvm(static libs) | llvm-static | llvm-dev |
| libuuid | libuuid-devel | uuid-dev     |
| openssl | openssl-devel | libssl-dev      |

Check if the following command works first:

```sh
llvm-config --link-static --libs lto
```

Build cctools:

```sh
./prebuilt-cctools/build-cctools.sh
```

##### (6) MSVC

1. Enter Visual Studio Developer Command Prompt first, then enter MSYS2/Cygwin shell.

2. Execute the shell script:

```sh
./prebuilt-msvc-sdk/extract_sdk_from_msvc.sh
```

3. Check and modify values of `VC_VERSION`, `WINDOWS_SDK_VERSION` in file `version` to match those of extracted SDKs in dir `prebuilt-msvc-sdk`.

##### (7) FreeBSD

```sh
./prebuilt-freebsd/prepare_sysroot.sh
```
##### (8) Open Harmony OS(OHOS)

```sh
# Set the installation path of OHOS SDK
export OHOS_SDK_HOME=/path/to/ohos-sdk
# Extract headers and libs from SDK
prebuilt-ohos/extract_sdk.sh
```

#### 4. Build and Assemble toolchain

Execute the script `build-all.sh` to start building.

```sh
./build-all.sh
```

The output directory path is defined by variable `OUTPUT_DIR` in the file `config`.

After building has finished successfully, you can use tool `strip_toolchain.sh` to strip the output toolchain.

### Project Reference

+ [llvm-mingw](https://github.com/mstorsjo/llvm-mingw)

+ [crosstool-ng](https://github.com/crosstool-ng/crosstool-ng)

+ [osxcross](https://github.com/tpoechtrager/osxcross)

