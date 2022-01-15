#include <stdint.h>
#include <pthread.h>
#include <string.h>

/* pthread */

int pthread_mutexattr_init(pthread_mutexattr_t *attr) {
    memset(attr, 0, sizeof(pthread_mutexattr_t));
    return 0;
}

int pthread_mutexattr_settype(pthread_mutexattr_t *attr, int type) {
    attr->__attr = type;
    return 0;
}

int pthread_mutexattr_gettype(const pthread_mutexattr_t *attr, int* out_type) {
    *out_type = attr->__attr;
    return 0;
}

int pthread_mutexattr_destroy(pthread_mutexattr_t *attr) {
    return 0;
}

extern int _pthread_cond_timedwait(pthread_cond_t *cond, pthread_mutex_t *mutex, uint64_t useconds);
int pthread_cond_timedwait(pthread_cond_t *cond, pthread_mutex_t *mutex, const struct timespec *abstime) {
    if (!abstime)
		return pthread_cond_wait(cond, mutex);
	return _pthread_cond_timedwait(cond, mutex, abstime->tv_sec * 1000000 + abstime->tv_nsec / 1000); 
}

int pthread_atfork(void (*prepare)(void), void (*parent)(void), void (*child)(void)) {
    // fork() not supported, so do nothing
    return 0;
}
