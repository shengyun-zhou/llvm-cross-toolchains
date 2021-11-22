import os
import sys
import subprocess
from sys import exit

DIR=os.path.dirname(__file__)

def main(target, exec_name):
    args = sys.argv[1:]
    lld_name = 'ld.lld'
    if 'apple' in target:
        lld_name = 'ld64.lld'
    elif 'wasm' in target:
        lld_name = 'wasm-ld'
    elif 'msvc' in target:
        if args[0].lower() == '/lib':
            # Generate static lib, act as lib.exe. It must be the first argument
            lld_name = 'lld-link'
        else:
            # Invoke lld-link via clang frontend to get MSVC lib path
            lld_name = '%s-clang' % target
            args = ['/clang:-Wl,' + arg for arg in args ]
    
    exec_prog = os.path.join(DIR, lld_name)
    os.execv(exec_prog, [exec_prog] + args)
