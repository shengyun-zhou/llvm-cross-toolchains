#include <unistd.h>

int getpagesize() {
    return sysconf(_SC_PAGESIZE);
}
