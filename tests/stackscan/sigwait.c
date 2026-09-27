/* LD_PRELOAD on the phone: a thread that gets SIGFPE, SIGSEGV, SIGBUS, SIGILL or SIGABRT prints
 * its tid and waits, so stackscan can read its stack (no gdb, no core dumps on the phone).
 * Build: arm-none-linux-gnueabi-gcc -shared -fPIC -O2 -o sigwait.so sigwait.c */
#include <signal.h>
#include <stdio.h>
#include <unistd.h>
#include <sys/syscall.h>

static void wait_here(int sig)
{
    char b[64];
    int n = snprintf(b, sizeof b, "sigwait: signal %d in tid %ld\n", sig, (long)syscall(SYS_gettid));
    write(2, b, n);
    for (;;)
        pause();
}

__attribute__((constructor)) static void install(void)
{
    static const int sigs[] = { SIGFPE, SIGSEGV, SIGBUS, SIGILL, SIGABRT };
    for (unsigned i = 0; i < sizeof sigs / sizeof *sigs; ++i)
        signal(sigs[i], wait_here);
}
