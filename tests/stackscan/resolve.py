#!/usr/bin/env python3
"""Names stackscan's "file+offset" lines: the phone's /home/user/qt5 is the box's build/devtree,
/opt/qt5 the staged sysroot, anything else the rootfs dump at /mnt/n9 (or ROOTFS).
Usage: resolve.py scan.txt   (on the box, after sourcing scripts/env.sh)"""
import bisect, os, re, subprocess, sys
W = os.environ["WORK"]; R = os.environ.get("ROOTFS", "/mnt/n9")
def local(p):
    for pre, to in (("/home/user/qt5/", W + "/build/devtree/"), ("/opt/qt5/", W + "/sysroot/opt/qt5/")):
        if p.startswith(pre): return to + p[len(pre):]
    return R + p
cache = {}
def syms(f):
    if f not in cache:
        loads = [tuple(int(x, 16) for x in l.split()[1:3]) for l in
                 subprocess.run(["readelf", "-lW", f], capture_output=True, text=True).stdout.splitlines()
                 if l.strip().startswith("LOAD") and " R E " in l]
        t = {}
        for args in (["-D"], []):
            for l in subprocess.run(["nm", "-C", "--defined-only", *args, f], capture_output=True, text=True).stdout.splitlines():
                m = re.match(r"([0-9a-f]+) [TtWw] (.*)", l)
                if m: t[int(m.group(1), 16) & ~1] = m.group(2)
        a = sorted(t); cache[f] = (loads, a, [t[x] for x in a])
    return cache[f]
for line in open(sys.argv[1]):
    m = re.match(r"(\S+)\+([0-9a-f]+)$", line.strip())
    if not m: print(line.rstrip()); continue
    f = local(m.group(1)); off = int(m.group(2), 16)
    if not os.path.exists(f): print(line.rstrip(), "(no local copy)"); continue
    loads, a, n = syms(f)
    va = next((off - po + pv for po, pv in loads), off)
    i = bisect.bisect_right(a, va) - 1
    print(f"{m.group(1).rsplit('/', 1)[-1]}+{off:x}  {n[i] + '+0x%x' % (va - a[i]) if i >= 0 else '?'}")
