#include <stdint.h>
#include <pthread.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <stdio.h>

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

int pthread_setcancelstate(int state, int *oldstate) {
    // A thread is not cancelable
    *oldstate = PTHREAD_CANCEL_DISABLE;
    return 0;
}

int pthread_setcanceltype(int type, int *oldtype) {
    *oldtype = 0;
    return 0;    
}

#undef pthread_cleanup_push
#undef pthread_cleanup_pop

struct cleanup_handler_stacknode {
    struct cleanup_handler_stacknode* next_node;
    void (*routine)(void *);
    void *arg;
};

_Thread_local struct cleanup_handler_stacknode* __thread_cleanup_handler_stacktop = NULL;

void pthread_cleanup_push(void (*routine)(void *), void *arg) {
    struct cleanup_handler_stacknode* new_node = (struct cleanup_handler_stacknode*)malloc(sizeof(struct cleanup_handler_stacknode));
    new_node->next_node = __thread_cleanup_handler_stacktop;
    new_node->routine = routine;
    new_node->arg = arg;
    __thread_cleanup_handler_stacktop = new_node;
}

void pthread_cleanup_pop(int execute) {
    if (__thread_cleanup_handler_stacktop) {
        struct cleanup_handler_stacknode* p_node = __thread_cleanup_handler_stacktop;
        __thread_cleanup_handler_stacktop = __thread_cleanup_handler_stacktop->next_node;
        if (execute)
            p_node->routine(p_node->arg);
        free(p_node);
    }
}

extern void _pthread_exit(void *retval);

void pthread_exit(void *retval) {
    while (__thread_cleanup_handler_stacktop)
        pthread_cleanup_pop(1);
    _pthread_exit(retval);
}

pthread_mutex_t __g_pthread_once_lock = PTHREAD_MUTEX_INITIALIZER;

void __attribute__((constructor)) __pthread_lib_init() {
    pthread_mutexattr_t mutex_attr;
    pthread_mutexattr_init(&mutex_attr);
    pthread_mutexattr_settype(&mutex_attr, PTHREAD_MUTEX_RECURSIVE);
    pthread_mutex_init(&__g_pthread_once_lock, &mutex_attr);
}

int pthread_once(pthread_once_t *once_control, void(*init_routine)()) {
    if (!once_control || !init_routine)
        return EINVAL;
    if (*once_control == 0) {
        pthread_mutex_lock(&__g_pthread_once_lock);
        init_routine();
        *once_control = 1;
        pthread_mutex_unlock(&__g_pthread_once_lock);
    }
    return 0;
}
