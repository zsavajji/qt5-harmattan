/* Task 0.2: proves a GCC 14 binary with the pinned loader runs on the phone, and
 * whether accept4() works on its 2.6.32 kernel (Qt's qt_safe_accept uses it).
 * Build: arm-none-linux-gnueabi-gcc -O2 -Wl,--dynamic-linker,/lib/ld-linux.so.3 device-check.c -o device-check */
#define _GNU_SOURCE
#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/syscall.h>
#include <unistd.h>

int main(void)
{
    printf("hello from gcc %d.%d\n", __GNUC__, __GNUC_MINOR__);

    /* On a socket that isn't listening, a working accept4 fails with EINVAL;
     * a missing one with ENOSYS. */
    int s = socket(AF_UNIX, SOCK_STREAM, 0);
    errno = 0;
    int r = accept4(s, 0, 0, SOCK_CLOEXEC);
    printf("glibc accept4: %d errno=%d (%s)\n", r, errno, strerror(errno));
    errno = 0;
    r = syscall(366 /* __NR_accept4 on ARM EABI */, s, 0, 0, SOCK_CLOEXEC);
    printf("raw accept4:   %d errno=%d (%s)\n", r, errno, strerror(errno));
    return 0;
}
