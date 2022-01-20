#include <errno.h>
#include <netinet/in.h>
#include <stdint.h>
#include <sys/socket.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/uio.h>
#include <ifaddrs.h>
#include <net/if.h>

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

struct wamr_ifaddr {
	char ifa_name[32];
    unsigned int ifa_ifindex;
	unsigned int ifa_flags;
	struct sockaddr_storage ifa_addr;
	struct sockaddr_storage ifa_netmask;
	union {
		struct sockaddr_storage ifu_broadaddr;
		struct sockaddr_storage ifu_dstaddr;
	} ifa_ifu;
	unsigned char ifa_hwaddr[6];
};

static volatile uint32_t __if_max_count = 10;

int32_t __imported_wasi_unstable_sock_getifaddrs(struct wamr_ifaddr *ifaddrs, uint32_t* addr_count) __attribute__((
    __import_module__("wasi_unstable"),
    __import_name__("sock_getifaddrs")
));

int __wamr_getifaddrs(struct wamr_ifaddr** out_ifaddrs, uint32_t* out_count) {
    uint32_t if_max_count = __atomic_load_n(&__if_max_count, __ATOMIC_RELAXED);
    uint32_t if_cur_count = if_max_count;
    *out_ifaddrs = (struct wamr_ifaddr*)malloc(sizeof(struct wamr_ifaddr) * if_cur_count);
    int32_t err = 0;
    while (1) {
        err = __imported_wasi_unstable_sock_getifaddrs(*out_ifaddrs, &if_cur_count);
        if (err == ENOBUFS && if_cur_count > if_max_count) {
            __atomic_store_n(&__if_max_count, if_cur_count, __ATOMIC_RELAXED);
            *out_ifaddrs = (struct wamr_ifaddr*)realloc(*out_ifaddrs, sizeof(struct wamr_ifaddr) * if_cur_count);
        } else if (err != 0) {
            errno = err;
            free(*out_ifaddrs);
            *out_ifaddrs = NULL;
            return -1;
        } else {
            if (if_cur_count == 0) {
                free(*out_ifaddrs);
                *out_ifaddrs = NULL;
            }
            *out_count = if_cur_count;
            return 0;
        }
    }
    return -1;
}

int getifaddrs(struct ifaddrs **ifap) {
    struct wamr_ifaddr* wamr_ifaddrs = NULL;
    uint32_t if_count = 0;
    if (__wamr_getifaddrs(&wamr_ifaddrs, &if_count) != 0)
        return -1;
    if (if_count == 0) {
        *ifap = NULL;
        return 0;
    }
    *ifap = (struct ifaddrs*)malloc(sizeof(struct ifaddrs) * if_count);
    struct ifaddrs* ifs = *ifap;
    struct ifaddrs_extdata* extdata_arr = (struct ifaddrs_extdata*)malloc(sizeof(struct ifaddrs_extdata) * if_count);
    for (uint32_t i = 0; i < if_count; i++) {
        memcpy(extdata_arr[i].ifa_hwaddr, wamr_ifaddrs[i].ifa_hwaddr, sizeof(wamr_ifaddrs->ifa_hwaddr));
        extdata_arr[i].ifa_ifindex = wamr_ifaddrs[i].ifa_ifindex;
    }
    for (uint32_t i = 0; i < if_count; i++) {
        memset(&ifs[i], 0, sizeof(*ifs));
        ifs[i].ifa_next = (i == if_count - 1) ? NULL : &ifs[i + 1];
        ifs[i].ifa_name = wamr_ifaddrs[i].ifa_name;
        ifs[i].ifa_flags = wamr_ifaddrs[i].ifa_flags;
        ifs[i].ifa_addr = (struct sockaddr*)&wamr_ifaddrs[i].ifa_addr;
        ifs[i].ifa_netmask = (struct sockaddr*)&wamr_ifaddrs[i].ifa_netmask;
        ifs[i].ifa_broadaddr = (struct sockaddr*)&wamr_ifaddrs[i].ifa_ifu.ifu_broadaddr;
        ifs[i].ifa_data = &extdata_arr[i];
    }
    return 0;
}

void freeifaddrs(struct ifaddrs *ifa) {
    if (!ifa)
        return;
    free(ifa->ifa_data);
    struct wamr_ifaddr* p_wamr_ifaddrs = (struct wamr_ifaddr*)ifa->ifa_name;
    free(p_wamr_ifaddrs);
    free(ifa);
}

unsigned int if_nametoindex(const char *ifname) {
    struct wamr_ifaddr* wamr_ifaddrs = NULL;
    uint32_t if_count = 0;
    if (__wamr_getifaddrs(&wamr_ifaddrs, &if_count) != 0 || if_count == 0)
        return 0;
    unsigned int idx = 0;
    for (uint32_t i = 0; i < if_count; i++) {
        if (strcmp(wamr_ifaddrs[i].ifa_name, ifname) == 0) {
            idx = wamr_ifaddrs[i].ifa_ifindex;
            break;
        }
    }
    free(wamr_ifaddrs);
    return idx;
}

char *if_indextoname(unsigned int ifindex, char *ifname) {
    struct wamr_ifaddr* wamr_ifaddrs = NULL;
    uint32_t if_count = 0;
    if (__wamr_getifaddrs(&wamr_ifaddrs, &if_count) != 0 || if_count == 0)
        return NULL;
    *ifname = 0;
    for (uint32_t i = 0; i < if_count; i++) {
        if (ifindex == wamr_ifaddrs[i].ifa_ifindex) {
            strncpy(ifname, wamr_ifaddrs[i].ifa_name, IF_NAMESIZE);
            break;
        }
    }
    return ifname;
}

struct if_nameindex *if_nameindex(void) {
    struct wamr_ifaddr* wamr_ifaddrs = NULL;
    uint32_t if_count = 0;
    if (__wamr_getifaddrs(&wamr_ifaddrs, &if_count) != 0 || if_count == 0)
        return NULL;
    struct if_nameindex *ret_arr = (struct if_nameindex *)malloc(sizeof(struct if_nameindex) * (if_count + 1));
    for (uint32_t i = 0; i < if_count; i++) {
        ret_arr[i].if_index = wamr_ifaddrs[i].ifa_ifindex;
        ret_arr[i].if_name = wamr_ifaddrs[i].ifa_name;
    }
    ret_arr[if_count].if_index = 0;
    ret_arr[if_count].if_name = NULL;
    return ret_arr;
}

void if_freenameindex(struct if_nameindex *ptr) {
    if (!ptr)
        return;
    struct wamr_ifaddr* p_wamr_ifaddrs = (struct wamr_ifaddr*)ptr->if_name;
    free(p_wamr_ifaddrs);
    free(ptr);
}
