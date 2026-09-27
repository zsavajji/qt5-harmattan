#!/usr/bin/env bash
# Phase 1: the headers the SDK sysroot lacks (into $SR/usr), then libxcb, the xcb-util
# family and libxkbcommon (into /opt/qt5, staged in $SR), then GCC 14's C++ runtime and
# OpenSSL with a CA bundle (Phase 4).
# Re-runnable: finished steps leave a stamp in $B; delete the stamp to redo a step.
# Ends with the Phase 1 "done when" check, which runs every time.
set -euo pipefail
. "$(dirname "$0")/env.sh"

SR=$WORK/sysroot
SRC=$WORK/src
B=$WORK/build/deps
Q=/opt/qt5
T=arm-none-linux-gnueabi
mkdir -p "$B/dl" "$SR$Q/lib"
find "$SR$Q/lib" -name '*.la' -delete   # see autotools()

# The toolchain's built-in sysroot is the SDK's, so name ours on every call.
export CC="$T-gcc --sysroot=$SR" CXX="$T-g++ --sysroot=$SR"
export AR=$T-gcc-ar RANLIB=$T-gcc-ranlib NM=$T-gcc-nm STRIP=$T-strip
export CFLAGS="-O2 -mtune=cortex-a8 -mthumb"
export LDFLAGS="-Wl,-rpath,$Q/lib -Wl,--disable-new-dtags"
# pkgconf prefixes $SR onto -I/-L and onto path variables (xcb-proto's xcbincludedir).
export PKG_CONFIG_SYSROOT_DIR=$SR
export PKG_CONFIG_LIBDIR=$SR$Q/lib/pkgconfig:$SR$Q/share/pkgconfig:$SR/usr/lib/pkgconfig:$SR/usr/share/pkgconfig
unset PKG_CONFIG_PATH

done_() { [ -f "$B/$1.done" ]; }
stamp() { touch "$B/$1.done"; echo "== $1 done"; }

fetch() { # url: download once into $B/dl and unpack there
    local f=$B/dl/${1##*/}
    [ -f "$f" ] || curl -fsSL -o "$f" "$1"
    tar -C "$B/dl" -xf "$f"
}

pc() { # name version libs requires [cflags]: a .pc for a library the sysroot ships without one
    cat > "$SR/usr/lib/pkgconfig/$1.pc" <<PC
prefix=/usr
libdir=\${prefix}/lib
includedir=\${prefix}/include

Name: $1
Description: $1, headers added for the Qt 5 build
Version: $2
Requires: $4
Libs: -L\${libdir} $3
Cflags: ${5:--I\${includedir}}
PC
}

autotools() { # source dir name, then extra configure args; out-of-tree build
    local n=$1; shift
    done_ "$n" && return
    # Our patches for this source, from patches/<name without version>/, applied once.
    for p in "$WORK/patches/${n%-*}"/*.patch; do
        [ -f "$p" ] || continue
        # "if", not "&&": an already applied patch must not end the loop with status 1 (set -e).
        if patch -d "$SRC/$n" -p1 -N -s --dry-run < "$p" >/dev/null; then patch -d "$SRC/$n" -p1 -N -s < "$p"; fi
    done
    rm -rf "${B:?}/$n" && mkdir -p "$B/$n" && cd "$B/$n"
    "$SRC/$n/configure" -q --host=$T --prefix=$Q --disable-static "$@"
    make -s -j6
    make -s install DESTDIR="$SR"
    # libtool archives name /opt/qt5 without the sysroot and break the next library's link.
    find "$SR$Q/lib" -name '*.la' -delete
    stamp "$n"
}

# --- 0. Headers the sysroot lacks (0.1), from the sysroot's exact versions ---------

# glibc's long double math declarations: already visible, harmattan-toolchain's sysroot.sh
# (scripts/build-toolchain.sh) made this sysroot.

# SGX's <GLES2/gl2platform.h> doesn't include <KHR/khrplatform.h> as the Khronos one does,
# and Qt's qopengles2ext.h needs its khronos_int64_t / khronos_uint64_t.
if ! done_ khrplatform; then
    sed -i 's|^#define __gl2platform_h_$|&\n#include <KHR/khrplatform.h> /* qt5-harmattan, see scripts/build-deps.sh */|' \
        "$SR/usr/include/GLES2/gl2platform.h"
    grep -q '^#include <KHR/khrplatform.h>' "$SR/usr/include/GLES2/gl2platform.h"
    stamp khrplatform
fi

if ! done_ headers; then
    # The sysroot's libxcb 1.7 dev files would shadow ours; its runtime .so.1 stays
    # because the system libX11 links against it.
    rm -rf "$SR/usr/include/xcb" "$SR/usr/lib/pkgconfig/xcb.pc" "$SR/usr/lib/libxcb.so" "$SR/usr/lib/libxcb.a"

    fetch https://xorg.freedesktop.org/releases/individual/lib/libX11-1.4.3.tar.bz2
    install -m644 "$B/dl/libX11-1.4.3/include/X11/Xlib-xcb.h" "$SR/usr/include/X11/"
    ln -sf libX11-xcb.so.1 "$SR/usr/lib/libX11-xcb.so"
    pc x11-xcb 1.4.3 -lX11-xcb "x11 xcb"

    fetch https://download.savannah.gnu.org/releases/freetype/freetype-old/freetype-2.4.3.tar.bz2
    mkdir -p "$SR/usr/include/freetype2"
    cp -r "$B/dl/freetype-2.4.3/include/." "$SR/usr/include/freetype2/"
    ln -sf libfreetype.so.6 "$SR/usr/lib/libfreetype.so"
    pc freetype2 12.1.6 -lfreetype "" '-I${includedir}/freetype2'   # 12.1.6 is 2.4.3's libtool version

    fetch https://www.freedesktop.org/software/fontconfig/release/fontconfig-2.8.0.tar.gz
    mkdir -p "$SR/usr/include/fontconfig"
    install -m644 "$B/dl/fontconfig-2.8.0/fontconfig/"*.h "$SR/usr/include/fontconfig/"
    ln -sf libfontconfig.so.1 "$SR/usr/lib/libfontconfig.so"
    pc fontconfig 2.8.0 -lfontconfig freetype2
    stamp headers
fi

# --- 1. xcb, xcb-util, xkbcommon into /opt/qt5 -------------------------------------

autotools xcb-proto-1.17.0
autotools libxcb-1.17.0 --enable-xinput --enable-xkb --disable-devel-docs --without-doxygen
autotools xcb-util-0.4.1
autotools xcb-util-image-0.4.1
autotools xcb-util-keysyms-0.4.1
autotools xcb-util-wm-0.4.2
autotools xcb-util-renderutil-0.3.10

if ! done_ libxkbcommon; then
    cat > "$B/cross.ini" <<INI
[binaries]
c = ['$T-gcc', '--sysroot=$SR']
ar = '$T-gcc-ar'
strip = '$T-strip'
pkg-config = 'pkg-config'

[built-in options]
# glibc 2.10's <assert.h> predates C11's static_assert macro (glibc 2.16).
c_args = ['-O2', '-mtune=cortex-a8', '-mthumb', '-Dstatic_assert=_Static_assert']
c_link_args = ['-Wl,-rpath,$Q/lib', '-Wl,--disable-new-dtags']

[properties]
sys_root = '$SR'
pkg_config_libdir = '$PKG_CONFIG_LIBDIR'

[host_machine]
system = 'linux'
cpu_family = 'arm'
cpu = 'cortex-a8'
endian = 'little'
INI
    rm -rf "$B/libxkbcommon"
    # Meson takes the compiler and flags from the cross file only.
    env -u CC -u CXX -u CFLAGS -u LDFLAGS meson setup "$B/libxkbcommon" "$SRC/libxkbcommon-1.13.2" \
        --cross-file "$B/cross.ini" --prefix=$Q --libdir=lib --buildtype=release \
        -Denable-x11=true -Denable-wayland=false -Denable-docs=false -Denable-tools=false \
        -Denable-xkbregistry=false -Denable-bash-completion=false \
        -Dxkb-config-root=/usr/share/X11/xkb -Dx-locale-root=/usr/share/X11/locale
    # Only the two libraries: the benchmark calls llroundl, which glibc 2.10's ARM <math.h>
    # doesn't declare (long double is double there).
    meson compile -C "$B/libxkbcommon" xkbcommon xkbcommon-x11
    DESTDIR="$SR" meson install -C "$B/libxkbcommon" --no-rebuild --quiet
    stamp libxkbcommon
fi

# --- 2. GCC 14's C++ runtime, found through DT_RPATH /opt/qt5/lib ----------------------

if ! done_ runtime; then
    L=$WORK/cross/$T/lib   # scripts/build-toolchain.sh
    cp -L "$L/libstdc++.so.6" "$L/libgcc_s.so.1" "$SR$Q/lib/"
    $T-strip --strip-unneeded "$SR$Q/lib/libstdc++.so.6" "$SR$Q/lib/libgcc_s.so.1"
    stamp runtime
fi

# --- 3. OpenSSL 3.5 LTS for QtNetwork (Phase 4), and a current CA bundle ----------------

OPENSSL=openssl-3.5.8
OPENSSL_SHA256=a8f84a39918ec6415ce765d9b429d313ba97b8143169c172e734b9514464f5b2
CACERT=cacert-2026-09-25.pem   # Mozilla's roots, from https://curl.se/docs/caextract.html
CACERT_SHA256=a41b5d356aea97a529fe27e0f7316d2f9d946d75927476cf9cf1b90637d00505

if ! done_ openssl; then
    f=$B/dl/$OPENSSL.tar.gz
    [ -f "$f" ] || curl -fsSL -o "$f" "https://github.com/openssl/openssl/releases/download/$OPENSSL/$OPENSSL.tar.gz"
    echo "$OPENSSL_SHA256  $f" | sha256sum -c --quiet
    rm -rf "${B:?}/$OPENSSL" && tar -C "$B" -xf "$f" && cd "$B/$OPENSSL"
    # linux-armv4: with OpenSSL's ARM assembly, NEON detected at run time. CC, CFLAGS and
    # LDFLAGS (sysroot, rpath) come from the environment above.
    ./Configure linux-armv4 shared no-tests no-docs --prefix=$Q --libdir=lib --openssldir=$Q/ssl
    make -j"$(nproc)"
    make DESTDIR="$SR" install_sw install_ssldirs >/dev/null
    $T-strip --strip-unneeded "$SR$Q"/lib/libssl.so.3 "$SR$Q"/lib/libcrypto.so.3
    # It links GCC's libatomic (64-bit atomics on ARMv7), which the phone doesn't have.
    cp -L "$WORK/cross/$T/lib/libatomic.so.1" "$SR$Q/lib/"
    $T-strip --strip-unneeded "$SR$Q/lib/libatomic.so.1"
    stamp openssl
fi

# The phone's roots are from 2011. Ours go one per file under their subject hash (<hash>.N),
# which OpenSSL's directory lookup (and Qt's on-demand root loading) expects.
if ! done_ cacert; then
    f=$B/dl/$CACERT
    [ -f "$f" ] || curl -fsSL -o "$f" "https://curl.se/ca/$CACERT"
    echo "$CACERT_SHA256  $f" | sha256sum -c --quiet
    d=$SR$Q/ssl/certs
    rm -rf "$d" && mkdir -p "$d"
    awk -v d="$d" '/BEGIN CERTIFICATE/ { f = sprintf("%s/new%03d.pem", d, ++n) }
                   f { print > f } /END CERTIFICATE/ { close(f); f = "" }' "$f"
    for c in "$d"/new*.pem; do
        h=$(openssl x509 -noout -subject_hash -in "$c") i=0
        while [ -e "$d/$h.$i" ]; do i=$((i + 1)); done
        mv "$c" "$d/$h.$i"
    done
    echo "== $(ls "$d" | wc -l) CA certificates from $CACERT"
    stamp cacert
fi

# --- Check: pkg-config finds everything, and every NEEDED resolves inside the sysroot ---

echo "== check"
fail=0
for m in xcb xcb-xkb xcb-xinput xcb-render xcb-shm xcb-randr xcb-shape xcb-sync xcb-xfixes \
         xcb-util xcb-image xcb-keysyms xcb-icccm xcb-renderutil xkbcommon xkbcommon-x11 \
         x11-xcb fontconfig freetype2 openssl; do
    v=$(pkg-config --modversion "$m" 2>/dev/null) || { echo "MISSING pkg-config: $m"; fail=1; continue; }
    printf '  %-16s %s\n' "$m" "$v"
done
[ "$(pkg-config --variable=libdir xcb)" = "$SR$Q/lib" ] || { echo "xcb resolves outside /opt/qt5"; fail=1; }
for so in "$SR$Q"/lib/*.so.*; do
    [ -L "$so" ] && continue
    for n in $($T-readelf -d "$so" | sed -n 's/.*(NEEDED).*\[\(.*\)\]/\1/p'); do
        [ -e "$SR$Q/lib/$n" ] || [ -e "$SR/usr/lib/$n" ] || [ -e "$SR/lib/$n" ] ||
            { echo "UNRESOLVED: ${so##*/} needs $n"; fail=1; }
    done
done
# Our libxcb replaces the system one process-wide, so it must define every xcb_ symbol
# the system libX11 uses, Nokia's xcb_poll_for_next_event included.
ours=$($T-nm -D --defined-only "$SR$Q/lib/libxcb.so.1" | awk '{print $3}')
for s in $($T-nm -D --undefined-only "$SR/usr/lib/libX11.so.6" | awk '{print $2}' | grep '^xcb_'); do
    grep -qx "$s" <<< "$ours" || { echo "MISSING in our libxcb: $s (the system libX11 needs it)"; fail=1; }
done
[ $fail = 0 ] && echo "== check passed" || { echo "== check FAILED"; exit 1; }
