#!/usr/bin/env bash
# 5.1: the SDK for other developers, $WORK/deb/qt5-harmattan-sdk-<version>-linux-x86_64.tar.xz:
# - cross/: our GCC 14; host/: Qt's host tools and mkspecs, with qt.conf; both stripped,
# - sysroot-overlay/ and sysroot-removed.txt: our changes to MADDE's Harmattan sysroot (/opt/qt5
#   with Qt's headers and libraries, the header fixes), applied by scripts/setup-sysroot.sh,
# - scripts/env.sh, cmake/, docs/developing.md (also README.md), sample-app/ and video-app/,
# - phone/: the runtime .debs from scripts/package.sh (run it first).
# MADDE stays a dependency (the sysroot, gendigsigsums). Everything is found through WORK, which
# env.sh takes from the bundle's location. Host binaries are from Ubuntu 26.04 (glibc 2.43).
set -euo pipefail
. "$(dirname "$0")/env.sh"

VERSION=5.15.19-9
NAME=qt5-harmattan-sdk-$VERSION-linux-x86_64
B=$WORK/build/sdk
S=$B/$NAME
rm -rf "${B:?}" && mkdir -p "$S/scripts" "$S/docs" "$WORK/deb"

rsync -a "$WORK/cross" "$WORK/host" "$WORK/cmake" "$WORK/sample-app" "$S/"
rsync -a "$WORK/tests/video-app/" "$S/video-app/"   # video with the GRP::video credential
rsync -a "$WORK/mkspecs/linux-harmattan-g++/" "$S/host/mkspecs/linux-harmattan-g++/"
cp "$WORK/scripts/env.sh" "$WORK/scripts/setup-sysroot.sh" "$S/scripts/"
cp "$WORK/docs/developing.md" "$S/docs/" && cp "$WORK/docs/developing.md" "$S/README.md"
# The phone runtime (scripts/package.sh), which every developer installs.
mkdir -p "$S/phone" && cp "$WORK"/deb/qt5-{harmattan,meego-components,meego-inputcontext,sample}_*_armel.deb "$S/phone/"

# Symbols off the host executables: GCC's cc1plus and lto1 are hundreds of MB with them.
find "$S/cross" "$S/host/bin" -type f -perm -u+x -print0 | xargs -0 file | \
    grep 'ELF 64-bit.*x86-64' | cut -d: -f1 | xargs strip --strip-unneeded

# Our sysroot against MADDE's, dry run with ours as the destination (MADDE is only read):
# '*deleting' is ours only, '>f.' changed by us, '>f+++' / 'cL+++' / 'cd+++' removed by us.
rsync -rlni --delete --exclude /usr/local/ "$MADDE_SYSROOT/" "$WORK/sysroot/" > "$B/diff.txt"
if grep -v '^\*deleting \|^>f\.\|^[>c][fdL]+++++++++ ' "$B/diff.txt"; then
    echo "unexpected sysroot differences above" >&2
    exit 1
fi
{ sed -n 's/^\*deleting *//p' "$B/diff.txt"; sed -n 's/^>f\.[^ ]* //p' "$B/diff.txt"; } > "$B/overlay.txt"
sed -n 's/^[>c][fdL]+++++++++ //p' "$B/diff.txt" > "$S/sysroot-removed.txt"
rsync -a --files-from="$B/overlay.txt" "$WORK/sysroot/" "$S/sysroot-overlay/"

tar -C "$B" -cf - "$NAME" | xz -T0 -6 > "$WORK/deb/$NAME.tar.xz"
echo "$(du -h "$WORK/deb/$NAME.tar.xz" | cut -f1)  $NAME.tar.xz ($(du -sh "$S" | cut -f1) unpacked;" \
     "overlay $(wc -l < "$B/overlay.txt") entries, $(wc -l < "$S/sysroot-removed.txt") removed)"
