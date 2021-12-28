#include <stdint.h>
#include <pthread.h>
#include <string.h>

int pthread_mutexattr_init(pthread_mutexattr_t *attr) {
    memset(attr, 0, sizeof(pthread_mutexattr_t));
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
