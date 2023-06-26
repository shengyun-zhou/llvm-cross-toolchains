package main

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"unicode"
)

func clangWrapperMain(execDir string, target string, execName string, cmdArgv []string) {
	inputArgv := cmdArgv[1:]
	arch := strings.Split(target, "-")[0]
	clangTarget := target
	clangExec := filepath.Join(execDir, "clang")
	toolchainRootDir := filepath.Dir(execDir)
	sysrootDir := filepath.Join(toolchainRootDir, target)
	clangArgs := []string{}
	clangLastArgs := []string{}
	linkerArgs := []string{}
	cPlusPlusMode := execName == "c++" || execName == "g++" || execName == "clang++"
	cPreProcessorMode := execName == "cpp"
	compileOnlyMode := cPreProcessorMode || inArray(inputArgv, "-c") || inArray(inputArgv, "/c") || inArray(inputArgv, "/C")
	fUseLD := "lld"

	if strings.HasPrefix(arch, "mips") {
		fUseLD = "ld"
		if !strings.Contains(arch, "64") {
			// Use mips32r2 ISA by default
			clangArgs = append(clangArgs, "-mips32r2")
		}
		if strings.HasSuffix(target, "sf") {
			clangArgs = append(clangArgs, "-msoft-float")
			if strings.Contains(target, "musl") && !inArray(inputArgv, "-static") {
				// Fix linker path
				linkerArgs = append(linkerArgs, "-Wl,-dynamic-linker=/lib/ld-musl-mipsel-sf.so.1")
			}
		}
		if strings.Contains(target, "linux") {
			clangArgs = append(clangArgs, "-no-pie")
		}
	} else if strings.HasPrefix(arch, "arm64") || strings.HasPrefix(arch, "aarch64") {
		if strings.Contains(target, "android") {
			clangArgs = append(clangArgs, "-isystem", filepath.Join(sysrootDir, "usr", "include", "aarch64-linux-android"))
		}
	} else if strings.HasPrefix(arch, "arm") {
		clangArgs = append(clangArgs, "-mthumb", "-Wa,-mimplicit-it=thumb")
		if arch == "arm" {
			clangArgs = append(clangArgs, "-march=armv7+nofp")
		}
		if strings.Contains(target, "android") {
			clangArgs = append(clangArgs, "-isystem", filepath.Join(sysrootDir, "usr", "include", "arm-linux-androideabi"))
		}
	} else if regexp.MustCompile("^i.86$").MatchString(arch) {
		if strings.Contains(target, "android") {
			clangArgs = append(clangArgs, "-isystem", filepath.Join(sysrootDir, "usr", "include", "i686-linux-android"))
		}
	} else if strings.HasPrefix(arch, "x86_64") {
		if strings.Contains(target, "android") {
			clangArgs = append(clangArgs, "-isystem", filepath.Join(sysrootDir, "usr", "include", "x86_64-linux-android"))
		}
	} else if strings.HasPrefix(arch, "wasm") {
		if strings.Contains(target, "emscripten") {
			emsdkPython := os.Getenv("EMSDK_PYTHON")
			if len(emsdkPython) == 0 {
				emsdkPython = "python3"
				os.Setenv("EMSDK_PYTHON", emsdkPython)
			}
			emcc := "emcc.py"
			if cPlusPlusMode {
				emcc = "em++.py"
			}
			clangArgs = append(clangArgs,
				"-Qunused-arguments",
				"-pthread",
			)
			linkerArgs = append(linkerArgs,
				"-sSTACK_SIZE=131072",
				"-sPTHREAD_POOL_SIZE=8",
				"-sINITIAL_MEMORY=16777216",
			)
			allArgs := []string{filepath.Join(toolchainRootDir, "emscripten", emcc)}
			allArgs = append(allArgs, clangArgs...)
			if !compileOnlyMode {
				allArgs = append(allArgs, linkerArgs...)
			}
			allArgs = append(allArgs, inputArgv...)
			allArgs = append(allArgs, clangLastArgs...)
			runCommand(emsdkPython, allArgs, nil)
			return
		} else if strings.Contains(target, "wamr") {
			clangArgs = append(clangArgs,
				"-D__wamr__",
				"-D_WASI_EMULATED_SIGNAL",
				"-D_WASI_EMULATED_PROCESS_CLOCKS",
				"-D_WASI_EMULATED_MMAN",
				"-D_WASI_EMULATED_GETPID",
				"-pthread",
			)
			linkerArgs = append(linkerArgs,
				"-Wl,--shared-memory",
				// Default memory configuration: stack size=128KB
				"-z", "stack-size=131072",
				"-Wl,--no-check-features",
				"-Wl,--export=__heap_base,--export=__data_end",
				// Build the WASM app as reactor(sub module) to avoid __wasm_call_ctors() and __wasm_call_dtors() to be called unexpectedly when the runtime call exported functions
				// See: https://github.com/WebAssembly/WASI/issues/471
				"-mexec-model=reactor", "-Wl,--export=__main_void,--export=__wasm_call_dtors",
			)
		}
	} else if strings.HasPrefix(arch, "loongarch") {
		fUseLD = "ld"
	}

	if !strings.Contains(target, "mingw") && !strings.Contains(target, "windows") && !strings.HasPrefix(arch, "wasm") {
		clangArgs = append(clangArgs, "-fPIC")
	}

	if strings.Contains(target, "android") {
		i := len(target) - 1
		for unicode.IsDigit(rune(target[i-1])) {
			i--
		}
		androidAPI, _ := strconv.Atoi(target[i:])
		if cPlusPlusMode && androidAPI < 24 {
			clangArgs = append(clangArgs, "-D_LIBCPP_HAS_NO_OFF_T_FUNCTIONS")
		}
	} else if strings.Contains(target, "apple") {
		// TODO: Use LLD if it"s mature enough for Apple
		fUseLD = "ld"
		sdkMinVersionArg := map[string]string{
			"MacOSX":           "-mmacosx-version-min=10.9",
			"iPhoneOS":         "-mios-version-min=9.0",
			"iPhoneSimulator":  "-mios-simulator-version-min=9.0",
			"AppleTVOS":        "-mtvos-version-min=9.0",
			"AppleTVSimulator": "-mtvos-simulator-version-min=9.0",
			"WatchOS":          "-mwatchos-version-min=3.0",
			"WatchSimulator":   "-mwatchos-simulator-version-min=3.0",
		}
		if strings.HasSuffix(target, "macosx") {
			clangArgs = append(clangArgs, sdkMinVersionArg["MacOSX"])
		} else if strings.HasSuffix(target, "ios-macabi") {
			clangArgs = append(clangArgs, "-mios-version-min=13.1")
		} else if strings.HasSuffix(target, "ios") || strings.HasSuffix(target, "iphoneos") {
			clangArgs = append(clangArgs, sdkMinVersionArg["iPhoneOS"])
		} else if strings.HasSuffix(target, "ios-simulator") {
			clangArgs = append(clangArgs, sdkMinVersionArg["iPhoneSimulator"])
		} else if strings.HasSuffix(target, "tvos") {
			clangArgs = append(clangArgs, sdkMinVersionArg["AppleTVOS"])
		} else if strings.HasSuffix(target, "tvos-simulator") {
			clangArgs = append(clangArgs, sdkMinVersionArg["AppleTVSimulator"])
		} else if strings.HasSuffix(target, "watchos") {
			clangArgs = append(clangArgs, sdkMinVersionArg["WatchOS"])
		} else if strings.HasSuffix(target, "watchos-simulator") {
			clangArgs = append(clangArgs, sdkMinVersionArg["WatchSimulator"])
		} else if strings.HasSuffix(target, "darwin") {
			// Special internal target apple-darwin
			if inArray(inputArgv, "-D__FORCE_APPLE_DARWIN_TARGET") {
				clangLastArgs = append(clangLastArgs, "-target", target)
			}
			sysrootDir = ""
			for i, arg := range inputArgv {
				if (arg == "--sysroot" || arg == "-isysroot") && i+1 < len(inputArgv) {
					sysrootDir = inputArgv[i+1]
					break
				}
			}
			if len(sysrootDir) == 0 {
				for _, p := range []StringStringPair{
					{"MacOSX", "x86_64"},
					{"iPhoneOS", "arm64"},
					{"iPhoneSimulator", "x86_64"},
					{"AppleTVOS", "arm64"},
					{"AppleTVSimulator", "x86_64"},
					{"WatchOS", "armv7"},
					{"WatchSimulator", "x86_64"},
				} {
					sdkName, defaultArch := p.first, p.second
					tempSysrootDir := filepath.Join(toolchainRootDir, sdkName+"-SDK")
					if statInfo, err := os.Stat(tempSysrootDir); !os.IsNotExist(err) && statInfo.IsDir() {
						sysrootDir = tempSysrootDir
						clangArgs = append(clangArgs, sdkMinVersionArg[sdkName])
						if !inArray(inputArgv, "-arch") {
							clangArgs = append(clangArgs, "-arch", defaultArch)
						}
						break
					}
				}
				if len(sysrootDir) == 0 {
					fmt.Fprintln(os.Stderr, "clang-wrapper: cannot find any Darwin SDK")
					os.Exit(1)
				}
			} else if !inArray(inputArgv, "-arch") {
				clangArgs = append(clangArgs, "-arch", "x86_64")
			}
		}
	}

	gnuAsDir := filepath.Join(execDir, "gnu-as", clangTarget)
	if statInfo, err := os.Stat(gnuAsDir); !os.IsNotExist(err) && statInfo.IsDir() {
		clangArgs = append(clangArgs, "-fno-integrated-as", "-B", gnuAsDir)
	}
	clangArgs = append(clangArgs,
		"-fuse-ld="+fUseLD,
		"-target", clangTarget,
		"-Qunused-arguments",
	)

	if strings.Contains(target, "msvc") {
		cPlusPlusMode = false
		cPreProcessorMode = false
		clangArgs = append(clangArgs, "-isystem", filepath.Join(sysrootDir, "include"))
		linkerArgs = append(linkerArgs, "/clang:-Wl,/libpath:"+filepath.Join(sysrootDir, "lib"))
		for i, arg := range clangArgs {
			clangArgs[i] = "/clang:" + arg
		}
		clangArgs = append(clangArgs,
			"--driver-mode=cl",
			"-vctoolsdir", filepath.Join(toolchainRootDir, "MSVC-SDK", "VC"),
			"-winsdkdir", filepath.Join(toolchainRootDir, "MSVC-SDK", "Windows-SDK"),
		)

		// Convert input arguments to accept some normal clang arguments
		for i, arg := range inputArgv {
			if strings.HasPrefix(arg, "--print") || strings.HasPrefix(arg, "-print") {
				inputArgv[i] = "/clang:" + arg
			}
		}
	} else {
		clangArgs = append(clangArgs,
			"--sysroot", sysrootDir,
			"-rtlib=compiler-rt",
		)
	}
	if cPlusPlusMode {
		clangArgs = append(clangArgs, "--driver-mode=g++", "-stdlib=libc++")
	} else if cPreProcessorMode {
		clangArgs = append(clangArgs, "--driver-mode=cpp")
	}
	allArgs := clangArgs
	if !compileOnlyMode {
		allArgs = append(allArgs, linkerArgs...)
	}
	allArgs = append(allArgs, inputArgv...)
	allArgs = append(allArgs, clangLastArgs...)
	runCommand(clangExec, allArgs, nil)
}
