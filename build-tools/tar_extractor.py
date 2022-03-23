#!/usr/bin/env python3
import tarfile
import os
import sys
import argparse
import shutil
from typing import Callable

USAGE_EXAMPLE_TEXT = '''Usage examples:
Extract to current directory: 
    python %s xxx.tar.gz
Extract to another directory:
    python %s xxx.tar.gz -C /path/to/destination''' % (os.path.basename(__file__), os.path.basename(__file__))

def do_mklink(link_path, target_path, is_dir, is_hardlink):
    if os.path.islink(link_path) or os.path.isfile(link_path):
        os.remove(link_path)
    elif os.path.isdir(link_path):
        shutil.rmtree(link_path)
    if is_hardlink:
        # Copy files(hardlink is not supported in some filesystems, such as NTFS)
        if os.path.isfile(target_path):
            shutil.copy2(target_path, link_path)
        else:
            shutil.copytree(target_path, link_path)
        return
    if sys.platform == 'win32':
        # / is valid in link_path, but invalid in target_path
        target_path = target_path.replace('/', '\\')
    os.symlink(target_path, link_path, target_is_directory=is_dir)

def extract_tar(tar_file, directory='.', strip_component_count=0, verbose_output_cb=None, progress_cb=None):
    tempfp = None
    if tar_file.endswith('.zst') or tar_file.endswith('.zstd'):
        import zstandard
        import tempfile
        dctx = zstandard.ZstdDecompressor()
        tempfp = tempfile.TemporaryFile()
        with open(tar_file, 'rb') as temp_tarfp:
            dctx.copy_stream(temp_tarfp, tempfp)
        tempfp.seek(0)
        target_tarfile = tarfile.open(fileobj=tempfp, encoding='utf-8')
    else:
        target_tarfile = tarfile.open(tar_file, 'r', encoding='utf-8')
    finished_member_count = 0
    previous_cwd = os.getcwd()
    os.chdir(directory)
    tar_link_members = []
    while True:
        if isinstance(progress_cb, Callable):
            progress_cb(finished_member_count)
        tar_member_info = target_tarfile.next()
        if tar_member_info is None:
            break
        # Drop original UID and GID to make all files belong to current user and group
        tar_member_info.uid = tar_member_info.gid = 0
        if tar_member_info.path.startswith('/'):
            # Do not allow absolute path
            tar_member_info.path = tar_member_info.path[1:]
        if strip_component_count > 0:
            path_split = tar_member_info.path.split('/', maxsplit=strip_component_count)
            if len(path_split) <= strip_component_count:
                finished_member_count += 1
                continue
            tar_member_info.path = path_split[-1]
        if os.name == 'nt':
            # Replace some unsupported characters
            tar_member_info.name = tar_member_info.name.replace(':', '_')
            tar_member_info.linkname = tar_member_info.linkname.replace(':', '_')
        if tar_member_info.islnk() or tar_member_info.issym():
            if tar_member_info.linkname.startswith('/'):
                tar_member_info.linkname = tar_member_info.linkname[1:]
            if isinstance(verbose_output_cb, Callable):
                verbose_output_cb('Enqueue link: %s -> %s' %(tar_member_info.name, tar_member_info.linkname))
            tar_link_members.append(tar_member_info)
            continue
        if isinstance(verbose_output_cb, Callable):
            verbose_output_cb('Extracting: %s' % tar_member_info.name)
        try:
            target_tarfile.extract(tar_member_info, numeric_owner=True)
        except FileNotFoundError:
            # Ignore non-exist file
            pass
        if not tar_member_info.isdir():
            finished_member_count += 1

    # Resolve links
    # NOTE: all hard links will be treat as symbolic links now
    while len(tar_link_members) > 0:
        unresolve_link_members = []
        for tar_member_info in tar_link_members:
            if tar_member_info.islnk():
                target_path = tar_member_info.linkname
            else:
                target_path = os.path.join(os.path.dirname(tar_member_info.name), tar_member_info.linkname)
            if not os.path.exists(target_path):
                unresolve_link_members.append(tar_member_info)
                continue
            if isinstance(verbose_output_cb, Callable):
                if tar_member_info.islnk():
                    verbose_output_cb('Copy: %s -> %s' %(tar_member_info.linkname, tar_member_info.name))
                else:
                    verbose_output_cb('Link: %s -> %s' %(tar_member_info.name, tar_member_info.linkname))
            do_mklink(tar_member_info.name, tar_member_info.linkname, os.path.isdir(target_path), tar_member_info.islnk())
            finished_member_count += 1
            if isinstance(progress_cb, Callable):
                progress_cb(finished_member_count)
        if len(unresolve_link_members) == len(tar_link_members):
            for tar_member_info in unresolve_link_members:
                if isinstance(verbose_output_cb, Callable):
                    verbose_output_cb('Link(broken): %s -> %s' %(tar_member_info.name, tar_member_info.linkname))
                # Create broken links
                do_mklink(tar_member_info.name, tar_member_info.linkname, False, False)
                finished_member_count += 1
                if isinstance(progress_cb, Callable):
                    progress_cb(finished_member_count)
            unresolve_link_members = []
        tar_link_members = unresolve_link_members
    target_tarfile.close()
    if tempfp:
        tempfp.close()
    os.chdir(previous_cwd)

if __name__ == '__main__':
    arg_parser = argparse.ArgumentParser(description='A tool to extract TAR files with symlink handling', 
                                         epilog=USAGE_EXAMPLE_TEXT, formatter_class=argparse.RawDescriptionHelpFormatter)
    arg_parser.add_argument('TAR_FILE', type=str, help='Input tar file')
    arg_parser.add_argument('-C', '--directory', metavar='DIR', type=str, default='.', help='Change to directory DIR')
    arg_parser.add_argument('--strip', '--strip-components', metavar='N', type=int, default=0, help='Strip N leading components from file')
    arg_parser.add_argument('-v', '--verbose', help="Verbose output", action='store_true')
    argv = vars(arg_parser.parse_args())
    extract_tar(argv['TAR_FILE'], directory=argv['directory'], strip_component_count=argv['strip'], verbose_output_cb=None if not argv['verbose'] else print)
