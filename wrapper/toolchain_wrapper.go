package main

import (
	"fmt"
	"os"
	"os/exec"
	"path"
	"strings"
)

func inArray(arr []string, target string) bool {
	for _, val := range arr {
		if val == target {
			return true
		}
	}
	return false
}

func runCommand(execPath string, argv []string, inputBytes []byte) {
	cmd := exec.Command(execPath, argv...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	stdin, err := cmd.StdinPipe()
	if err != nil {
		panic(err)
	}
	err = cmd.Start()
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	if len(inputBytes) > 0 {
		stdin.Write(inputBytes)
	}
	stdin.Close()
	cmd.Wait()
	os.Exit(cmd.ProcessState.ExitCode())
}

func main() {
	execDir, err := os.Executable()
	if err != nil {
		panic(err)
	}
	execDir = path.Dir(execDir)
	os.Setenv("PATH", execDir+string(os.PathListSeparator)+os.Getenv("PATH"))
	basename := path.Base(os.Args[0])
	basename = strings.TrimSuffix(basename, path.Ext(basename))
	_tempSplit := strings.Split(basename, "-")
	execName := _tempSplit[len(_tempSplit)-1]
	target := strings.TrimSuffix(basename, "-"+execName)
	if target == basename {
		fmt.Fprintln(os.Stderr, "toolchain-wrapper: cannot run tools without target triple prefix")
		os.Exit(1)
	}
	if inArray([]string{"clang", "clang++", "cc", "c++", "gcc", "g++", "as", "cl"}, execName) {
		clangWrapperMain(execDir, target, execName, os.Args)
	} else if strings.Contains(target, "apple-") {
		ccToolsWrapperMain(execDir, target, execName, os.Args)
	} else if inArray([]string{"ld", "link"}, execName) {
		lldWrapperMain(execDir, target, execName, os.Args)
	} else {
		fmt.Fprintln(os.Stderr, "toolchain-wrapper: cannot find correspond wrapper for "+basename)
		os.Exit(1)
	}
}
