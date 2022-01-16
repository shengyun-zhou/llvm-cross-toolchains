#include <errno.h>
#include <netinet/in.h>
#include <stdint.h>
#include <sys/socket.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/uio.h>

int32_t __imported_wasi_unstable_sock_socket(int32_t domain, int32_t type, int32_t protocol, int32_t* out_sockfd) __attribute__((
    __import_module__("wasi_unstable"),
    __import_name__("sock_socket")
));

int socket(int domain, int type, int protocol) {
    int32_t sockfd = -1;
    int32_t err = __imported_wasi_unstable_sock_socket(domain, type, protocol, &sockfd);
    if (err != 0) {
        errno = err;
        return -1;
    }
    return sockfd;
}

int32_t __imported_wasi_unstable_sock_bind(int32_t sockfd, const struct sockaddr *addr, uint32_t addrlen) __attribute__((
    __import_module__("wasi_unstable"),
    __import_name__("sock_bind")
));

int bind(int sockfd, const struct sockaddr *addr, socklen_t addrlen) {
    int32_t err = __imported_wasi_unstable_sock_bind(sockfd, addr, addrlen);
    if (err != 0) {
        errno = err;
        return -1;
    }
    return 0;
}

int32_t __imported_wasi_unstable_sock_connect(int32_t sockfd, const struct sockaddr *addr, uint32_t addrlen) __attribute__((
    __import_module__("wasi_unstable"),
    __import_name__("sock_connect")
));

int connect(int sockfd, const struct sockaddr *addr, socklen_t addrlen) {
    int32_t err = __imported_wasi_unstable_sock_connect(sockfd, addr, addrlen);
    if (err != 0) {
        errno = err;
        return -1;
    }
    return 0;
}

int32_t __imported_wasi_unstable_sock_listen(int32_t sockfd, int32_t backlog) __attribute__((
    __import_module__("wasi_unstable"),
    __import_name__("sock_listen")
));

int listen(int sockfd, int backlog) {
    int32_t err = __imported_wasi_unstable_sock_listen(sockfd, backlog);
    if (err != 0) {
        errno = err;
        return -1;
    }
    return 0;
}

int32_t __imported_wasi_unstable_sock_accept(int32_t sockfd, struct sockaddr *addr, uint32_t* addrlen) __attribute__((
    __import_module__("wasi_unstable"),
    __import_name__("sock_accept")
));

int accept(int sockfd, struct sockaddr *addr, socklen_t *addrlen) {
    uint32_t wasi_addrlen = 0;
    if (addrlen)
        wasi_addrlen = *addrlen;
    int32_t err = __imported_wasi_unstable_sock_accept(sockfd, addr, &wasi_addrlen);
    if (err != 0) {
        errno = err;
        return -1;
    }
    if (addrlen)
        *addrlen = wasi_addrlen;
    return 0;
}

int32_t __imported_wasi_unstable_sock_getopt(int32_t sockfd, int32_t level, int32_t optname, void *optval, uint32_t *optlen) __attribute__((
    __import_module__("wasi_unstable"),
    __import_name__("sock_getopt")
));

int getsockopt(int sockfd, int level, int optname, void *optval, socklen_t *optlen) {
    if (!optval || !optlen) {
        errno = EINVAL;
        return -1;
    }
    uint32_t wasi_optlen = *optlen;
    int32_t ret = __imported_wasi_unstable_sock_getopt(sockfd, level, optname, optval, &wasi_optlen);
    if (ret != 0) {
        errno = ret;
        return -1;
    }
    *optlen = wasi_optlen;
    return 0;
}

int32_t __imported_wasi_unstable_sock_setopt(int32_t sockfd, int32_t level, int32_t optname, const void *optval, uint32_t optlen) __attribute__((
    __import_module__("wasi_unstable"),
    __import_name__("sock_setopt")
));

int setsockopt(int sockfd, int level, int optname, const void *optval, socklen_t optlen) {
    int32_t ret = __imported_wasi_unstable_sock_setopt(sockfd, level, optname, optval, optlen);
    if (ret != 0) { 
        errno = ret;
        return -1;
    }
    return 0;
}

ssize_t recvfrom(int sock, void *restrict buffer, size_t length, int flags, struct sockaddr *restrict address,
                 socklen_t *restrict address_len) {
    struct msghdr msg;
    memset(&msg, 0, sizeof(msg));
    struct iovec tempiovec;
    tempiovec.iov_base = buffer;
    tempiovec.iov_len = length;
    msg.msg_iov = &tempiovec;
    msg.msg_iovlen = 1;
    msg.msg_name = address;
    msg.msg_namelen = address_len ? *address_len : 0;
    ssize_t ret = recvmsg(sock, &msg, flags);
    if (address_len)
        *address_len = msg.msg_namelen;
    return ret;
}

int32_t __imported_wasi_unstable_sock_recvfrom(int32_t sock, const struct iovec* iov, uint32_t iovlen, int32_t flags, void* ip_buf, uint32_t ip_bufsize,
                                               uint32_t* ret_datasize, uint32_t* ret_recvflags) __attribute__((
    __import_module__("wasi_unstable"),
    __import_name__("sock_recvfrom")
));

ssize_t recvmsg(int sock, struct msghdr *message, int flags) {
    uint32_t ret_datasize = 0;
    uint32_t ret_recvflags = 0;
    int32_t err = __imported_wasi_unstable_sock_recvfrom(sock, message->msg_iov, message->msg_iovlen, flags, message->msg_name, message->msg_namelen, &ret_datasize, &ret_recvflags);
    if (err != 0) {
        errno = err;
        return -1;
    }
    message->msg_flags = ret_recvflags;
    return ret_datasize;
}

ssize_t sendto(int sock, const void *message, size_t length, int flags, const struct sockaddr *dest_addr,
               socklen_t dest_len) {
    struct msghdr msg;
    memset(&msg, 0, sizeof(msg));
    struct iovec tempiovec;
    tempiovec.iov_base = (void*)message;
    tempiovec.iov_len = length;
    msg.msg_iov = &tempiovec;
    msg.msg_iovlen = 1;
    msg.msg_name = (void*)dest_addr;
    msg.msg_namelen = dest_len;
    return sendmsg(sock, &msg, flags);
}

int32_t __imported_wasi_unstable_sock_sendto(int32_t sock, const struct iovec* iov, uint32_t iovlen, int32_t flags, const struct sockaddr* ip_buf, uint32_t ip_bufsize,
                                             uint32_t* ret_datasize) __attribute__((
    __import_module__("wasi_unstable"),
    __import_name__("sock_sendto")
));

ssize_t sendmsg(int sock, const struct msghdr *msg, int flags) {
    uint32_t ret_datasize = 0;
    int32_t err = __imported_wasi_unstable_sock_sendto(sock, msg->msg_iov, msg->msg_iovlen, flags, (struct sockaddr*)msg->msg_name, msg->msg_namelen, &ret_datasize);
    if (err != 0) {
        errno = err;
        return -1;
    }
    return ret_datasize;
}

int32_t __imported_wasi_unstable_sock_getsockname(int32_t sockfd, struct sockaddr *addr, uint32_t* addrlen) __attribute__((
    __import_module__("wasi_unstable"),
    __import_name__("sock_getsockname")
));

int getsockname(int sockfd, struct sockaddr *addr, socklen_t *addrlen) {
    if (!addr || !addrlen) {
        errno = EINVAL;
        return -1;
    }
    uint32_t wasi_addrlen = *addrlen;
    int32_t err = __imported_wasi_unstable_sock_getsockname(sockfd, addr, &wasi_addrlen);
    if (err != 0) {
        errno = err;
        return -1;
    }
    *addrlen = wasi_addrlen;
    return 0;
}

int32_t __imported_wasi_unstable_sock_getpeername(int32_t sockfd, struct sockaddr *addr, uint32_t* addrlen) __attribute__((
    __import_module__("wasi_unstable"),
    __import_name__("sock_getpeername")
));

int getpeername(int sockfd, struct sockaddr *addr, socklen_t *addrlen) {
    if (!addr || !addrlen) {
        errno = EINVAL;
        return -1;
    }
    uint32_t wasi_addrlen = *addrlen;
    int32_t err = __imported_wasi_unstable_sock_getpeername(sockfd, addr, &wasi_addrlen);
    if (err != 0) {
        errno = err;
        return -1;
    }
    *addrlen = wasi_addrlen;
    return 0;
}
