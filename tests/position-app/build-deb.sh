#!/usr/bin/env bash
# Builds qt5-positiontest_1.0_armel.deb into <WORK>/deb, with its Aegis manifest as the _aegis
# member (what MADDE's packaging adds). Source the SDK's scripts/env.sh first.
set -euo pipefail
: "${WORK:?source <sdk>/scripts/env.sh first}"
SRC=$(cd "$(dirname "$0")" && pwd)
B=$WORK/build/position-app
d=$B/qt5-positiontest
rm -rf "$B" && mkdir -p "$B/obj" "$d/DEBIAN" "$WORK/deb"
(cd "$B/obj" && "$WORK/host/bin/qmake" "$SRC/position-app.pro" >/dev/null && make -s -j6 >/dev/null && make -s install INSTALL_ROOT="$d" >/dev/null)
# The dev-tree variant (position-app.pro, CONFIG+=dev) and its qt.conf.
mkdir -p "$B/obj-dev"
(cd "$B/obj-dev" && "$WORK/host/bin/qmake" CONFIG+=dev "$SRC/position-app.pro" >/dev/null && make -s -j6 >/dev/null && make -s install INSTALL_ROOT="$d" >/dev/null)
printf '[Paths]\nPrefix=/home/user/qt5\n' > "$d/opt/qt5-positiontest/dev/bin/qt.conf"
install -D -m 644 "$SRC/qt5-positiontest.desktop" "$d/usr/share/applications/qt5-positiontest.desktop"
install -D -m 644 "$SRC/qt5-positiontest80.png" "$d/usr/share/icons/hicolor/80x80/apps/qt5-positiontest80.png"
cat > "$d/DEBIAN/control" <<CONTROL
Package: qt5-positiontest
Version: 1.0
Architecture: armel
Maintainer: ${MAINTAINER:-Andrea Faggin <blackbird5308@gmail.com>}
Installed-Size: $(du -sk --exclude=DEBIAN "$d" | cut -f1)
Section: user/other
Priority: optional
Depends: qt5-harmattan (>= 5.15.19-9)
Description: Qt 5 position test
 Positions and satellites from positioningd through QtPositioning, with Location.
 qt5-positiontest-dev: the same with Qt from /home/user/qt5 (the dev tree).
CONTROL
(cd "$d" && find . -type f ! -path './DEBIAN/*' -printf '%P\0' | xargs -0 md5sum > DEBIAN/md5sums)
perl "$QT_SDK_PATH/Madde/madbin/gendigsigsums" -o com.nokia.maemo "$d.digsigsums" "$d"
mv "$d.digsigsums" "$d/DEBIAN/digsigsums"
deb=$WORK/deb/qt5-positiontest_1.0_armel.deb
chmod -R go-w "$d"   # the box's umask (002) left group-writable directories
dpkg-deb --root-owner-group -Zgzip --build "$d" "$deb" >/dev/null
cp "$SRC/qt5-positiontest.aegis" "$B/_aegis"
(cd "$B" && ar q "$deb" _aegis)
ar t "$deb"
