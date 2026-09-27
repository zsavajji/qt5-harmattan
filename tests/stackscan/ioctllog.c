/* LD_PRELOAD on the phone: logs every failing ioctl (fd, request, errno) and every omapfb memory
 * request (OMAPFB_SETUP_MEM/QUERY_MEM, with the size) to stderr.
 * Build: arm-none-linux-gnueabi-gcc -shared -fPIC -O2 -o ioctllog.so ioctllog.c -ldl */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <errno.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <sys/syscall.h>

int ioctl(int fd, unsigned long req, ...)
{
    static int (*real)(int, unsigned long, void *);
    va_list ap;
    va_start(ap, req);
    void *arg = va_arg(ap, void *);
    va_end(ap);
    if (!real)
        real = (int (*)(int, unsigned long, void *))dlsym(RTLD_NEXT, "ioctl");
    int r = real(fd, req, arg);
    int e = errno;
    char b[160];
    if (req == 0x40084f37 || req == 0x40084f38) { /* struct omapfb_mem_info { u32 size; u8 type; } */
        int n = snprintf(b, sizeof b, "ioctllog: tid %ld fd %d %s size %u -> %d %s\n", (long)syscall(SYS_gettid), fd,
                         req == 0x40084f37 ? "SETUP_MEM" : "QUERY_MEM", *(unsigned *)arg, r, r < 0 ? strerror(e) : "");
        write(2, b, n);
    } else if (r < 0 && e != EAGAIN && e != ENOTTY) {
        int n = snprintf(b, sizeof b, "ioctllog: tid %ld fd %d req %#lx -> %s\n", (long)syscall(SYS_gettid), fd, req, strerror(e));
        write(2, b, n);
    }
    errno = e;
    return r;
}
