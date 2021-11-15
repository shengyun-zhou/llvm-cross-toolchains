import sys
import os
from sys import exit

if __name__ == '__main__':
    os.environ['PATH'] = os.path.dirname(__file__) + os.path.pathsep + os.environ['PATH']
    # Set path of CA certs
    os.environ['SSL_CERT_FILE'] = os.path.join(os.path.dirname(__file__), 'cacert.pem')
    if '__ARG0' in os.environ:
        sys.argv[0] = os.environ['__ARG0']

    basename = os.path.splitext(os.path.basename(sys.argv[0]))[0]
    target = basename.rsplit('-', maxsplit=1)[0]
    exec_name = basename.rsplit('-', maxsplit=1)[-1]
    if target == basename:
        sys.stderr.write('toolchain-wrapper: cannot run tools without target triple prefix\n')
        exit(1)
    if exec_name in ('clang', 'clang++', 'cc', 'c++', 'gcc', 'g++', 'as', 'cl'):
        import clang_wrapper
        clang_wrapper.main(target, exec_name)
    elif 'apple-' in target:
        import cctools_wrapper
        cctools_wrapper.main(target, exec_name)
    elif exec_name in ('ld', 'link'):
        import lld_wrapper
        lld_wrapper.main(target, exec_name)
    else:
        sys.stderr.write('toolchain-wrapper: cannot find correspond wrapper for %s\n' % basename)
        exit(1)
    
