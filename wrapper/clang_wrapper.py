import os
import sys
import fnmatch
import subprocess
from sys import exit

DIR=os.path.dirname(__file__)

def main(target, exec_name):
    arch = target.split('-')[0]
    clang_target = target
    clang_exec = os.path.join(DIR, 'clang')
    sysroot_dir = os.path.join(DIR, '../%s' % target)
    clang_args = []
    cplusplus_mode = exec_name in ('c++', 'g++', 'clang++')
    fuse_ld = 'lld'
    
    if arch.startswith('mips'):
        if not '64' in arch:
            # Use mips32 ISA by default
            clang_args += ['-mips32']
        if target.endswith('sf'):
            clang_args += ['-msoft-float']
            if target == 'mipsel-linux-muslsf' and '-static' not in sys.argv[1:]:
                # Fix linker path
                clang_args += ['-Wl,-dynamic-linker=/lib/ld-musl-mipsel-sf.so.1']
        if 'linux' in target:
            clang_args += ['-no-pie']
    elif arch.startswith('aarch64') or arch.startswith('arm64'):
        if 'android' in target:
            clang_args += ['-isystem', os.path.join(sysroot_dir, 'usr/include/aarch64-linux-android')]
    elif arch.startswith('arm'):
        clang_args += ['-mthumb']
        if 'android' in target:
            clang_args += ['-isystem', os.path.join(sysroot_dir, 'usr/include/arm-linux-androideabi')]
    elif fnmatch.fnmatch(arch, 'i*86'):
        if 'android' in target:
            clang_args += ['-isystem', os.path.join(sysroot_dir, 'usr/include/i686-linux-android')]
    elif arch.startswith('x86_64'):
        if 'android' in target:
            clang_args += ['-isystem', os.path.join(sysroot_dir, 'usr/include/x86_64-linux-android')]
    elif arch.startswith('riscv'):
        # TODO: Use LLD after it has implemented linker relaxation for RISC-V
        fuse_ld = 'ld'

    if not 'mingw' in target and not 'windows' in target and not 'cygwin' in target:
        clang_args += ['-fPIC']

    if 'cygwin' in target:
        if '__GCC_AS_LD' in os.environ:
            gcc_ld_args = [
                '--sysroot', sysroot_dir,
                '-B', os.path.join(DIR, '%s-' % target),
                '-L' + os.path.join(sysroot_dir, 'usr/lib/w32api'),
                '-static-libgcc', '-v'
            ]
            if cplusplus_mode:
                gcc_ld_args += ['-lc++']
            exit(subprocess.run([os.path.join(DIR, '%s-gcc-ld' % target)] + sys.argv[1:] + gcc_ld_args).returncode)
        else:
            fuse_ld = ''
            clang_args += ['-D_GNU_SOURCE']
            if cplusplus_mode:
                clang_args += ['-D_LIBCPP_OBJECT_FORMAT_COFF', '-D_LIBCPP_HAS_THREAD_API_PTHREAD']
            os.environ['__GCC_AS_LD'] = '1'     # Clang may call gcc as linker later
    elif 'apple' in target:
        # TODO: Use LLD if it's mature enough for Apple
        fuse_ld = 'ld'
        sdk_min_version_arg = {
            'MacOSX': '-mmacosx-version-min=10.9',
            'iPhoneOS': '-mios-version-min=9.0',
            'iPhoneSimulator': '-mios-simulator-version-min=9.0',
            'AppleTVOS': '-mtvos-version-min=9.0',
            'AppleTVSimulator': '-mtvos-simulator-version-min=9.0',
            'WatchOS': '-mwatchos-version-min=3.0',
            'WatchSimulator': '-mwatchos-simulator-version-min=3.0'
        }
        if target.endswith('macosx'):
            clang_args += [sdk_min_version_arg['MacOSX']]
        elif target.endswith('ios-macabi'):
            clang_args += ['-mios-version-min=13.1']
        elif target.endswith('ios') or target.endswith('iphoneos'):
            clang_args += [sdk_min_version_arg['iPhoneOS']]
        elif target.endswith('ios-simulator'):
            clang_args += [sdk_min_version_arg['iPhoneSimulator']]
        elif target.endswith('tvos'):
            clang_args += [sdk_min_version_arg['AppleTVOS']]
        elif target.endswith('tvos-simulator'):
            clang_args += [sdk_min_version_arg['AppleTVSimulator']]
        elif target.endswith('watchos'):
            clang_args += [sdk_min_version_arg['WatchOS']]
        elif target.endswith('watchos-simulator'):
            clang_args += [sdk_min_version_arg['WatchSimulator']]
        elif target.endswith('darwin'):     # Special internal target apple-darwin
            sysroot_dir = ''
            args = sys.argv[1:]
            for i, arg in enumerate(args):
                if arg in ('--sysroot', '-isysroot') and i + 1 < len(args):
                    sysroot_dir = args[i + 1]
                    break
            if not sysroot_dir:
                for sdk_name, default_arch in {
                    'MacOSX': 'x86_64',
                    'iPhoneOS': 'arm64',
                    'iPhoneSimulator': 'x86_64',
                    'AppleTVOS': 'arm64',
                    'AppleTVSimulator': 'x86_64',
                    'WatchOS': 'armv7',
                    'WatchSimulator': 'x86_64',
                }.items():
                    temp_sysroot_dir = os.path.join(DIR, '../%s-SDK' % sdk_name)
                    if os.path.isdir(temp_sysroot_dir):
                        sysroot_dir = temp_sysroot_dir
                        clang_args += [sdk_min_version_arg[sdk_name]]
                        if '-arch' not in sys.argv[1:]:
                            clang_args += ['-arch', default_arch]
                        break
                
                if not sysroot_dir:
                    sys.stderr.write('clang-wrapper: cannot find any Darwin SDK\n')
                    exit(1)
            elif '-arch' not in sys.argv[1:]:
                clang_args += ['-arch', 'x86_64']

    if fuse_ld:
        clang_args += ['-fuse-ld=%s' % fuse_ld]
    clang_args += [
        '-target', clang_target,
        '-Qunused-arguments'
    ]

    input_args = sys.argv[1:]
    if 'msvc' in target:
        clang_args += [
            '-isystem', os.path.join(sysroot_dir, 'include'),
        ]
        if '-c' not in input_args and '/c' not in input_args and '/C' not in input_args:
            # Cannot specify additional library path in compile-only mode.
            clang_args += ['-Wl,/libpath:' + os.path.join(sysroot_dir, 'lib')]
        clang_args = ['/clang:' + arg for arg in clang_args]
        clang_args += [
            '--driver-mode=cl',
            '-vctoolsdir', os.path.join(DIR, '../MSVC-SDK/VC'),
            '-winsdkdir', os.path.join(DIR, '../MSVC-SDK/Windows-SDK')
        ]
        # Convert input arguments to accept some normal clang arguments
        temp_input_args = []
        for arg in input_args:
            if arg.startswith('--print') or arg.startswith('-print'):
                temp_input_args += ['/clang:' + arg]
            else:
                temp_input_args += [arg]
        input_args = temp_input_args
    else:
        clang_args += [
            '--sysroot', sysroot_dir,
            '-rtlib=compiler-rt',
        ]

    if cplusplus_mode and 'msvc' not in target:
        clang_args += ['--driver-mode=g++', '-stdlib=libc++']

    exit(subprocess.run([clang_exec] + clang_args + input_args).returncode)
