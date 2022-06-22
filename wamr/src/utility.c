#include <errno.h>
#include <sys/utsname.h>
#include <unistd.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <signal.h>

int getpagesize() {
    return sysconf(_SC_PAGESIZE);
}

int gethostname(char *name, size_t len) {
    // Ref: https://code.woboq.org/userspace/glibc/sysdeps/posix/gethostname.c.html
    struct utsname buf;
    size_t node_len;
    if (uname(&buf) != 0)
        return -1;
    node_len = strlen(buf.nodename) + 1;
    memcpy(name, buf.nodename, len < node_len ? len : node_len);
    if (node_len > len) {
      errno = ENAMETOOLONG;
      return -1;
    }
    return 0;
}
int sethostname(const char *name, size_t len) { errno = EPERM; return -1; }

FILE *popen(const char *command, const char *type) {
    // Do not allow to execute any command now.
    errno = ENOENT;
    return NULL;
}
int system(const char *cmd) { return 127; }
int pclose(FILE *stream) { return 0; }

void *__cxa_allocate_exception(size_t thrown_size)
{
    return malloc(thrown_size);
}

_Thread_local int __tls_h_errno = 0;
int *__h_errno_location() { return &__tls_h_errno; }

int sigprocmask(int how, const sigset_t* set, sigset_t* oldset) { errno = ENOSYS; return -1; }
