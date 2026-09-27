#!/usr/bin/env bash
# The phone's dev tree /home/user/qt5 for qt5-cameratest-dev (tests/camera-app): the staged Qt with
# every ELF file's RPATH set to /home/user/qt5/lib, so the dev tree loads only itself and never
# the installed /opt/qt5 (the plain staged files keep /opt/qt5/lib, and a plugin's own RPATH won:
# a process got both copies). Built in $WORK/build/devtree, then streamed to the phone.
#   devtree.sh               everything
#   devtree.sh lib/libX.so   given files (relative to /opt/qt5), after rebuilding them
# PHONE: ssh target of the phone (default user@n9). Run on the box.
set -euo pipefail
. "$(dirname "$0")/env.sh"
PHONE=${PHONE:-user@n9}
SQ=$WORK/sysroot/opt/qt5
D=$WORK/build/devtree
PATCHELF=$WORK/host/bin/patchelf   # built from src/patchelf (0.18.0)
paths=("$@")
[ ${#paths[@]} -gt 0 ] || paths=(bin lib plugins qml ssl/certs)
mkdir -p "$D"
for p in "${paths[@]}"; do
    rsync -a --exclude=pkgconfig --exclude=cmake --exclude='*.prl' --exclude='*.a' --exclude='*.la' \
        "$SQ/$p" "$D/$(dirname "$p")/"
done
n=0
while IFS= read -r -d '' f; do
    rp=$("$PATCHELF" --print-rpath "$f" 2>/dev/null) || continue
    case "$rp" in *"/opt/qt5/lib"*)
        "$PATCHELF" --force-rpath --set-rpath "${rp//\/opt\/qt5\/lib//home/user/qt5/lib}" "$f"; n=$((n+1));;
    esac
done < <(cd "$D" && find "${paths[@]}" -type f -print0 | sed -z "s#^#$D/#")
echo "RPATH set on $n files"
tar -C "$D" -c "${paths[@]}" | ssh -o LogLevel=ERROR "$PHONE" 'mkdir -p /home/user/qt5 && tar -C /home/user/qt5 -x && sync'
