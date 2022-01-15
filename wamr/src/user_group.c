#include <unistd.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/time.h>
#include <utime.h>
#include <fcntl.h>

uid_t getuid() { return 0; }
uid_t geteuid() { return 0; }
uid_t getgid() { return 0; }
gid_t getegid() { return 0; }

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

