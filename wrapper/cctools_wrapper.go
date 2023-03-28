package main

import (
	"io/ioutil"
	"os"
	"path/filepath"
	"runtime"
	"strings"

	shlex "github.com/kballard/go-shellquote"
)

func winPath2WSLPath(winPath string) string {
	if runtime.GOOS != "windows" {
		return winPath
	}
	winPath = strings.Replace(winPath, "\\", "/", -1)
	if !filepath.IsAbs(winPath) {
		return winPath
	}
	absPathSplit := strings.SplitN(winPath, ":/", 2)
	return "/mnt/" + strings.ToLower(absPathSplit[0]) + "/" + absPathSplit[1]
}

func ccToolsHandleCmdlineArg(targetExec string, arg string) []string {
	arg = strings.Replace(arg, "\\", "/", -1) // Prevent argument to be escaped, and there is no \ in UNIX-styled arguments
	if strings.HasPrefix(arg, "@") {          // Response file, but cctools do not support it.
		respFile := arg[1:]
		content, err := ioutil.ReadFile(respFile)
		if err == nil {
			tempArgs, err := shlex.Split(string(content))
			if err == nil {
				retArgs := []string{}
				for _, tempArg := range tempArgs {
					retArgs = append(retArgs, ccToolsHandleCmdlineArg(targetExec, tempArg)...)
				}
				return retArgs
			}
		}
		return []string{arg}
	}

	if runtime.GOOS != "windows" {
		return []string{arg}
	}
	if strings.HasSuffix(targetExec, "-ld") {
		// Linker
		if strings.HasPrefix(arg, "-l") || strings.HasPrefix(arg, "-L") {
			// Link lib or link directory
			return []string{arg[:2] + winPath2WSLPath(arg[2:])}
		}
	}
	dirName := filepath.Dir(arg)
	if len(dirName) > 0 && dirName != "." {
		_, err := os.Stat(dirName)
		if err == nil {
			return []string{winPath2WSLPath(arg)}
		}
	}
	argSplit := strings.SplitN(arg, "=", 2)
	if len(argSplit) == 2 {
		dirName = filepath.Dir(argSplit[1])
		_, err := os.Stat(dirName)
		if err == nil {
			return []string{argSplit[0] + "=" + winPath2WSLPath(argSplit[1])}
		}
	}
	return []string{arg}
}

func ccToolsWrapperMain(execDir string, target string, execName string, cmdArgv []string) {
	targetExec := filepath.Join(execDir, "cctools-"+execName)
	runArgs := []string{}
	shellEvelArgs := []string{}
	if runtime.GOOS == "windows" {
		wslDistro := os.Getenv("LLVM_CROSS_WSL_DISTRO")
		if len(wslDistro) > 0 {
			runArgs = append(runArgs, "-d", wslDistro)
		}
		// Pass remaining arguments via stdin becuase command line length is limited to only 32767 characters
		// Ref: https://docs.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-createprocessa
		runArgs = append(runArgs, "--", "sh", "-c", "$(cat -)")
		shellEvelArgs = append(shellEvelArgs, winPath2WSLPath(targetExec))
	}
	for _, arg := range cmdArgv[1:] {
		shellEvelArgs = append(shellEvelArgs, ccToolsHandleCmdlineArg(targetExec, arg)...)
	}
	if runtime.GOOS == "windows" {
		runCommand("wsl", runArgs, []byte(shlex.Join(shellEvelArgs...)))
	} else {
		runCommand(targetExec, append(runArgs, shellEvelArgs...), nil)
	}
}
