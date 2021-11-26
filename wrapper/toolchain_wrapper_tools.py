import subprocess
import os
import sys

def exec_subprocess(argv):
    if sys.platform not in ('win32',):
        os.execv(argv[0], argv)
    else:
        sys.exit(subprocess.run(argv).returncode)
