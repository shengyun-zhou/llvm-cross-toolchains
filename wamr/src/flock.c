#include <fcntl.h>
#include <sys/file.h>
#include <errno.h>

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
