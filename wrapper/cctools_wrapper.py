import os
import sys
import subprocess
import shlex
from sys import exit

DIR=os.path.dirname(__file__)

def win_path_to_wsl_path(win_path):
    if sys.platform not in ('win32', 'cygwin'):
        return win_path
    win_path = win_path.replace('\\', '/')
    if not os.path.isabs(win_path):
        return win_path
    if win_path.startswith('/'):
        # MSYS2/Cygwin path, convert it to Windows path first
        return win_path_to_wsl_path(subprocess.check_output(["cygpath", "-w", win_path]).strip().decode())
    abspath_split = win_path.split(':/', maxsplit=1)
    # Starts with // to prevent MSYS2/Cygwin converting it to Windows path again 
    return '//mnt/' + abspath_split[0].lower() + '/' + abspath_split[1]

def handle_cmdline_arg(target_exec, arg):
    arg = arg.replace('\\', '/')    # Prevent argument to be escaped, and there is no \ in UNIX-styled arguments
    if arg.startswith('@'):         # Response file, but cctools do not support it.
        resp_file = arg[1:]
        if os.path.isfile(resp_file):
            with open(resp_file, 'r') as f:
                resp_file_args = shlex.split(f.read())
            retargs = []
            for temp_arg in resp_file_args:
                retargs += handle_cmdline_arg(target_exec, temp_arg)
            return retargs
        else:
            return [arg]
        
    if sys.platform not in ('win32', 'cygwin'):
        return [arg]
    if target_exec.endswith('-ld'):     # Linker
        if arg.startswith('-l') or arg.startswith('-L'):    # Link lib or link directory
            return [arg[:2] + win_path_to_wsl_path(arg[2:])]
    dir_name = os.path.dirname(arg)
    if dir_name and os.path.exists(dir_name):
        return [win_path_to_wsl_path(arg)]
    else:
        arg_split = arg.split('=', maxsplit=1)
        if len(arg_split) == 1:
            return [arg]
        else:
            dir_name = os.path.dirname(arg_split[1])
            if dir_name and os.path.exists(dir_name):
                return [arg_split[0] + '=' + win_path_to_wsl_path(arg_split[1])]
            else:
                return [arg]

def main(target, exec_name):
    target_exec = os.path.join(DIR, 'cctools-' + exec_name)
    run_args = []
    shell_eval_args = []
    if sys.platform in ('win32', 'cygwin'):
        run_args += ['wsl']
        wsl_distro = os.environ.get('LLVM_CROSS_WSL_DISTRO')
        if wsl_distro:
            run_args += ['-d', wsl_distro]
        # Pass remaining arguments via stdin becuase command line length is limited to only 32767 characters
        # Ref: https://docs.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-createprocessa
        run_args += ['--', 'sh', '-c', '$(cat -)']
        shell_eval_args += [win_path_to_wsl_path(target_exec)]
    for arg in sys.argv[1:]:
        shell_eval_args += handle_cmdline_arg(target_exec, arg)

    if sys.platform not in ('win32', 'cygwin'):
        os.execv(target_exec, [target_exec] + run_args + shell_eval_args)
    else:
        quote_args = [shlex.quote(arg) for arg in shell_eval_args]
        shell_eval_cmdline_bytes = (' '.join(quote_args)).encode('utf-8')
        exit(subprocess.run(run_args, input=shell_eval_cmdline_bytes).returncode)
