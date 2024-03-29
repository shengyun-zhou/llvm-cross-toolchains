package main

import (
	"path/filepath"
	"strings"
)

func lldWrapperMain(execDir string, target string, execName string, cmdArgv []string) {
	cmdArgv = cmdArgv[1:]
	lldName := "ld.lld"
	if strings.Contains(target, "apple-") {
		lldName = "ld64.lld"
	} else if strings.HasPrefix(target, "wasm") {
		lldName = "wasm-ld"
	} else if strings.Contains(target, "msvc") {
		if len(cmdArgv) > 0 && strings.ToLower(cmdArgv[0]) == "/lib" {
			// Generate static lib, act as lib.exe. It must be the first argument
			lldName = "lld-link"
		} else {
			// Invoke lld-link via clang frontend to get MSVC lib path
			lldName = target + "-clang"
			for i, arg := range cmdArgv {
				cmdArgv[i] = "/clang:-Wl," + arg
			}
		}
	}
	lldExec := filepath.Join(execDir, lldName)
	runCommand(lldExec, cmdArgv, nil)
}
