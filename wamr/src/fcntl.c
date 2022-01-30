#include <wasi/api.h>
#include <errno.h>
#include <fcntl.h>
#include <stdarg.h>

int32_t __imported_wasi_unstable_fd_fcntl_flock(int32_t fd, int32_t cmd, struct flock *flock_buf) __attribute__((
    __import_module__("wasi_unstable"),
    __import_name__("fd_fcntl_flock")
));

int fcntl(int fildes, int cmd, ...) {
  switch (cmd) {
    case F_GETFD:
      // Act as if the close-on-exec flag is always set.
      return FD_CLOEXEC;
    case F_SETFD:
      // The close-on-exec flag is ignored.
      return 0;
    case F_GETFL: {
      // Obtain the flags and the rights of the descriptor.
      __wasi_fdstat_t fds;
      __wasi_errno_t error = __wasi_fd_fdstat_get(fildes, &fds);
      if (error != 0) {
        errno = error;
        return -1;
      }

      // Roughly approximate the access mode by converting the rights.
      int oflags = fds.fs_flags;
      if ((fds.fs_rights_base &
           (__WASI_RIGHTS_FD_READ | __WASI_RIGHTS_FD_READDIR)) != 0) {
        if ((fds.fs_rights_base & __WASI_RIGHTS_FD_WRITE) != 0)
          oflags |= O_RDWR;
        else
          oflags |= O_RDONLY;
      } else if ((fds.fs_rights_base & __WASI_RIGHTS_FD_WRITE) != 0) {
        oflags |= O_WRONLY;
      } else {
        oflags |= O_SEARCH;
      }
      return oflags;
    }
    case F_SETFL: {
      // Set new file descriptor flags.
      va_list ap;
      va_start(ap, cmd);
      int flags = va_arg(ap, int);
      va_end(ap);

      __wasi_fdflags_t fs_flags = flags & 0xfff;
      __wasi_errno_t error =
          __wasi_fd_fdstat_set_flags(fildes, fs_flags);
      if (error != 0) {
        errno = error;
        return -1;
      }
      return 0;
    }
    case F_SETLK:
    case F_SETLKW:
    case F_GETLK: {
      va_list ap;
      va_start(ap, cmd);
      struct flock* flock_buf = va_arg(ap, struct flock*);
      va_end(ap);
      
      int32_t error = __imported_wasi_unstable_fd_fcntl_flock(fildes, cmd, flock_buf);
      if (error != 0) {
        errno = error;
        return -1;
      }
      return 0;
    }
    default:
      errno = EINVAL;
      return -1;
  }
}
