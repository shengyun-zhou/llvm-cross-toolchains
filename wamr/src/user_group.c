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
