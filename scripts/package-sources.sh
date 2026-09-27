#!/usr/bin/env bash
# A release's corresponding source (Qt and most libraries here are LGPL/GPL, GCC and binutils
# GPL): OUT/qt5-harmattan-sources-<version>.tar with this checkout's committed tree (scripts,
# patches), every upstream tree the phone packages and the SDK are built from, at its pinned
# commit (scripts/fetch-sources.sh), and the downloaded tarballs (OpenSSL, the CA bundle,
# binutils, GCC and GCC's prerequisites). Run on the box after a build.
set -euo pipefail
. "$(dirname "$0")/env.sh"
VERSION=${VERSION:-5.15.19-9}   # as scripts/package.sh
OUT=${OUT:-$WORK/deb}
N=qt5-harmattan-sources-$VERSION
R=$WORK/build/sources/$N
rm -rf "$WORK/build/sources" && mkdir -p "$R/upstream" "$OUT"
git -C "$WORK" archive --prefix=qt5-harmattan/ -o "$R/qt5-harmattan.tar.gz" HEAD
# Pristine trees (git archive leaves out the applied patches: they're in patches/).
for m in qtbase qtdeclarative qtsvg qtmultimedia qtsensors qtgraphicaleffects qtimageformats \
         qtwebsockets qtquickcontrols2 qtlocation qtconnectivity qtfeedback qt-components \
         qtinsider-maliit sensorfw libxkbcommon-1.13.2; do
    git -C "$WORK/src/$m" archive --prefix="$m/" -o "$R/upstream/$m.tar.gz" HEAD
done
for t in xcb-proto-1.17.0 libxcb-1.17.0 xcb-util-0.4.1 xcb-util-image-0.4.1 \
         xcb-util-keysyms-0.4.1 xcb-util-wm-0.4.2 xcb-util-renderutil-0.3.10; do
    tar -C "$WORK/src" -czf "$R/upstream/$t.tar.gz" "$t"   # as built: libxcb with its patch
done
cp "$WORK"/build/deps/dl/openssl-*.tar.gz "$WORK"/build/deps/dl/cacert-*.pem "$R/upstream/"
T=$WORK/build/toolchain
cp "$T/binutils-2.42.tar.xz" "$T/gcc-14.2.0.tar.xz" "$T"/gcc-14.2.0/*.tar.* "$R/upstream/"
tar -C "$WORK/build/sources" -cf "$OUT/$N.tar" "$N"
rm -rf "$WORK/build/sources"
ls -lh "$OUT/$N.tar"
