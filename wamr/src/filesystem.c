#include <unistd.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/time.h>
#include <utime.h>
#include <fcntl.h>
#include <sys/file.h>
#include <sys/statvfs.h>
#include <stdint.h>
#include <wasi/api.h>
#include <string.h>

int chown(const char *path, uid_t owner, gid_t group) { errno = ENOSYS; return -1; }
int fchownat(int fd, const char *path, uid_t owner, gid_t group, int flag) { errno = ENOSYS; return -1; }
int fchown(int fildes, uid_t owner, gid_t group) { errno = ENOSYS; return -1; }
int chmod(const char *pathname, mode_t mode) { errno = ENOSYS; return -1; }
int fchmod(int fd, mode_t mode) { errno = ENOSYS; return -1; }
int fchmodat(int dirfd, const char *pathname, mode_t mode, int flags) { errno = ENOSYS; return -1; }
mode_t umask(mode_t mask) { return S_IRGRP | S_IROTH; }

int utimes(const char *filename, const struct timeval times[2]) {
    struct utimbuf utime_buf;
    utime_buf.actime = times[0].tv_sec +  times[0].tv_usec / 1000000;
    utime_buf.modtime = times[1].tv_sec + times[1].tv_usec / 1000000;
    return utime(filename, &utime_buf);
}

int flock (int fd, int operation) {
    // Emulate as a call to fcntl().
    // Ref: glibc(https://code.woboq.org/userspace/glibc/sysdeps/posix/flock.c.html)
    struct flock lbuf;
    switch (operation & ~LOCK_NB) {
        case LOCK_SH:
            lbuf.l_type = F_RDLCK;
            break;
        case LOCK_EX:
            lbuf.l_type = F_WRLCK;
            break;
        case LOCK_UN:
            lbuf.l_type = F_UNLCK;
            break;
        default:
            errno = EINVAL;
            return -1;
    }
    lbuf.l_whence = SEEK_SET;
    lbuf.l_start = lbuf.l_len = 0L;
    return fcntl (fd, (operation & LOCK_NB) ? F_SETLK : F_SETLKW, &lbuf);
}

struct wamr_statvfs {
    uint32_t f_bsize;
    uint64_t f_blocks;
    uint64_t f_bfree;
    uint64_t f_bavail;
};

void __wamr_statvfs_to_statvfs(const struct wamr_statvfs *internal_buf, struct statvfs *out_buf) {
    memset(out_buf, 0, sizeof(*out_buf));
    out_buf->f_bsize = out_buf->f_frsize = internal_buf->f_bsize;
    out_buf->f_blocks = internal_buf->f_blocks;
    out_buf->f_bfree = internal_buf->f_bfree;
    out_buf->f_bavail = internal_buf->f_bavail;
}

int32_t __imported_wasi_unstable_path_statvfs(const char *path, uint32_t pathlen, struct wamr_statvfs *buf) __attribute__((
    __import_module__("wasi_unstable"),
    __import_name__("path_statvfs")
));

int statvfs(const char *path, struct statvfs *buf) {
    uint32_t pathlen = strlen(path);
    struct wamr_statvfs internal_vfs_buf;
    int32_t err = __imported_wasi_unstable_path_statvfs(path, pathlen, &internal_vfs_buf);
    if (err != 0) {
        errno = err;
        return -1;
    }
    __wamr_statvfs_to_statvfs(&internal_vfs_buf, buf);
    return 0;
}

int32_t __imported_wasi_unstable_fd_statvfs(int32_t fd, struct wamr_statvfs *buf) __attribute__((
    __import_module__("wasi_unstable"),
    __import_name__("fd_statvfs")
));

int fstatvfs(int fd, struct statvfs *buf) {
    struct wamr_statvfs internal_vfs_buf;
    int32_t err = __imported_wasi_unstable_fd_statvfs(fd, &internal_vfs_buf);
    if (err != 0) {
        errno = err;
        return -1;
    }
    __wamr_statvfs_to_statvfs(&internal_vfs_buf, buf);
    return 0;
}
