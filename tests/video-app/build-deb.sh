#!/usr/bin/env bash
# Builds qt5-videotest_1.0_armel.deb into <WORK>/deb, with its Aegis manifest as the _aegis
# member (what MADDE's packaging adds). Source the SDK's scripts/env.sh first.
set -euo pipefail
: "${WORK:?source <sdk>/scripts/env.sh first}"
SRC=$(cd "$(dirname "$0")" && pwd)
B=$WORK/build/video-app
d=$B/qt5-videotest
rm -rf "$B" && mkdir -p "$B/obj" "$d/DEBIAN" "$WORK/deb"
(cd "$B/obj" && "$WORK/host/bin/qmake" "$SRC/video-app.pro" >/dev/null && make -s -j6 >/dev/null && make -s install INSTALL_ROOT="$d" >/dev/null)
install -D -m 644 "$SRC/qt5-videotest.desktop" "$d/usr/share/applications/qt5-videotest.desktop"
install -D -m 644 "$SRC/qt5-videotest80.png" "$d/usr/share/icons/hicolor/80x80/apps/qt5-videotest80.png"
cat > "$d/DEBIAN/control" <<CONTROL
Package: qt5-videotest
Version: 1.0
Architecture: armel
Maintainer: ${MAINTAINER:-Andrea Faggin <blackbird5308@gmail.com>}
Installed-Size: $(du -sk --exclude=DEBIAN "$d" | cut -f1)
Section: user/other
Priority: optional
Depends: qt5-harmattan (>= 5.15.19-5)
Description: Qt 5 video test
 Plays a stock video through QtMultimedia, with GRP::video for zero-copy frames.
CONTROL
(cd "$d" && find . -type f ! -path './DEBIAN/*' -printf '%P\0' | xargs -0 md5sum > DEBIAN/md5sums)
perl "$QT_SDK_PATH/Madde/madbin/gendigsigsums" -o com.nokia.maemo "$d.digsigsums" "$d"
mv "$d.digsigsums" "$d/DEBIAN/digsigsums"
deb=$WORK/deb/qt5-videotest_1.0_armel.deb
chmod -R go-w "$d"   # the box's umask (002) left group-writable directories
dpkg-deb --root-owner-group -Zgzip --build "$d" "$deb" >/dev/null
cp "$SRC/qt5-videotest.aegis" "$B/_aegis"
(cd "$B" && ar q "$deb" _aegis)
ar t "$deb"
