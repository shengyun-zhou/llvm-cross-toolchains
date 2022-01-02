#include <iostream>
#include <cstdio>
#include <atomic>
#include <cstdint>
#include <mutex>
#include <thread>
#include <vector>
#include <memory>

thread_local int g = 0;

void thread_msg(int idx, const std::string& msg) {
    std::cout << "thread " << idx << " says: " << msg << std::endl;
    g++;
    std::cout << "TLS var g of thread " << idx << " is: " << g << std::endl;
}

int main() {
    std::vector<std::shared_ptr<std::thread>> threads;
    for (int i = 1; i <= 4; i++)
        threads.push_back(std::make_shared<std::thread>(thread_msg, i, "Hello"));
    for (auto& t : threads)
        t->join();
    threads.clear();

    std::atomic<uint64_t> n(0);
    n++;
    std::cout << "Hello world" << std::endl << n.load() << std::endl;
    return 0;
}
