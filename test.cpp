#include <iostream>
#include <cstdio>
#include <atomic>
#include <cstdint>

thread_local int g = 0;

int main() {
    std::atomic<uint64_t> n(0);
    n++;
    std::cout << "Hello world" << std::endl << n.load() << std::endl;
    return 0;
}
