#include "native-wrapper.h"

#define TOOLCHAIN_WRAPPER _T("toolchain_wrapper.py")

#ifndef _WIN32
#define tsgetenv getenv
#define tsputenv putenv
#define tsaccess access
#elif defined(_UNICODE)
#define tsgetenv _wgetenv
#define tsputenv _wputenv
#define tsaccess _waccess
#else
#define tsgetenv getenv
#define tsputenv _putenv
#define tsaccess _access
#endif

int main(int argc, TCHAR* argv[]) {
    const TCHAR* dir;
    const TCHAR* basename;
    const TCHAR* target;
    const TCHAR* exename = NULL;
    split_argv(argv[0], &dir, &basename, &target, &exename);

    tsputenv(concat(_T("__ARG0="), argv[0]));
    const TCHAR** new_argv = (const TCHAR**)malloc(sizeof(TCHAR*) * (argc + 2));
    const TCHAR* env_python_exec = tsgetenv(_T("LLVM_CROSS_PYTHON"));
    if (env_python_exec && env_python_exec[0]) {
        new_argv[0] = env_python_exec;
    } else {
        // Use embeded python3 first
#ifndef _WIN32
        new_argv[0] = concat(dir, _T("../python_embed/bin/python3"));
#else
        new_argv[0] = concat(dir, _T("..\\python_embed\\python.exe"));
#endif
        if (tsaccess(new_argv[0], 04) == -1) {
#ifndef _WIN32
            new_argv[0] = _T("python3");
#else
            new_argv[0] = _T("python.exe");
#endif
        }
    }
    new_argv[1] = concat(dir, TOOLCHAIN_WRAPPER);
    for (int i = 1; i < argc; i++)
        new_argv[i + 1] = argv[i];
    new_argv[argc + 1] = NULL;
    return run_final(new_argv[0], new_argv);
}
