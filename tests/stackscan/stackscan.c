/* Poor man's backtrace for the phone (no gdb): scans a thread's stack for words that point
 * into executable mappings and prints them as file+offset, for addr2line/nm on the box.
 * Usage: stackscan <pid> [tid] [words]   (same user; tid defaults to pid) */
#define _GNU_SOURCE
#define _FILE_OFFSET_BITS 64
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/ptrace.h>
#include <sys/wait.h>

struct map { unsigned long lo, hi, off; char path[256]; };

int main(int argc, char **argv)
{
    if (argc < 2) { fprintf(stderr, "usage: stackscan pid [tid] [words]\n"); return 1; }
    int pid = atoi(argv[1]), tid = argc > 2 ? atoi(argv[2]) : pid, words = argc > 3 ? atoi(argv[3]) : 4096;
    char fn[64], line[512];
    static struct map maps[1024]; int n = 0;
    snprintf(fn, sizeof fn, "/proc/%d/maps", pid);
    FILE *f = fopen(fn, "r");
    if (!f) { perror(fn); return 1; }
    while (n < 1024 && fgets(line, sizeof line, f)) {
        char perm[8]; struct map m = { 0 };
        if (sscanf(line, "%lx-%lx %7s %lx %*s %*s %255s", &m.lo, &m.hi, perm, &m.off, m.path) >= 4 && perm[2] == 'x')
            maps[n++] = m;
    }
    fclose(f);
    /* stat field 29 is kstkesp, 30 kstkeip */
    snprintf(fn, sizeof fn, "/proc/%d/task/%d/stat", pid, tid);
    f = fopen(fn, "r");
    if (!f || !fgets(line, sizeof line, f)) { perror(fn); return 1; }
    fclose(f);
    char *p = strrchr(line, ')') + 2; unsigned long sp = 0, pc = 0;
    for (int field = 3; field <= 30 && p; ++field) {
        if (field == 29) sp = strtoul(p, NULL, 10);
        if (field == 30) pc = strtoul(p, NULL, 10);
        p = strchr(p, ' '); if (p) ++p;
    }
    /* 2.6.32 lets only an attached tracer read /proc/<pid>/mem */
    /* ... checked against the main thread's tracer: attach to it too for another thread */
    if (ptrace(PTRACE_ATTACH, tid, 0, 0) < 0) { perror("ptrace attach"); return 1; }
    waitpid(tid, NULL, __WALL);
    if (tid != pid) {
        if (ptrace(PTRACE_ATTACH, pid, 0, 0) < 0) { perror("ptrace attach pid"); return 1; }
        waitpid(pid, NULL, __WALL);
    }
    snprintf(fn, sizeof fn, "/proc/%d/mem", pid);
    int fd = open(fn, O_RDONLY);
    if (fd < 0) { perror(fn); return 1; }
    unsigned long *buf = malloc(words * sizeof *buf);
    ssize_t got = pread(fd, buf, words * sizeof *buf, (off_t)sp);
    if (got <= 0) { perror("pread"); return 1; }
    ptrace(PTRACE_DETACH, tid, 0, 0);
    if (tid != pid)
        ptrace(PTRACE_DETACH, pid, 0, 0);
    printf("pc %08lx sp %08lx\n", pc, sp);
    for (unsigned long a = pc, i = 0; i <= (unsigned long)got / sizeof *buf; a = buf[i++])
        for (int k = 0; k < n; ++k)
            if (a >= maps[k].lo && a < maps[k].hi) {
                printf("%s+%lx\n", maps[k].path, a - maps[k].lo + maps[k].off);
                break;
            }
    return 0;
}
