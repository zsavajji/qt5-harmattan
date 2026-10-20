#!/usr/bin/env bash
# 5.1: build the .debs from the staged /opt/qt5 in $WORK/sysroot, into $WORK/deb/. Run on the box
# after build-qt.sh. The user installs them (root).
#   qt5-harmattan           Qt libraries with our libstdc++, libgcc_s, libxcb* and libxkbcommon,
#                           the plugins, and qtdeclarative's QML modules
#   qt5-meego-components    com.nokia.meego, com.meego and Qt.labs.components (with .qmlc)
#   qt5-meego-inputcontext  the Maliit input context (the stock keyboard)
#   qt5-sample              sample-app/, a com.nokia.meego app in the app grid
# Each has DEBIAN/digsigsums (closed mode checks it; open mode ignores it) and md5sums. gzip
# members: the phone's dpkg is 1.15.
# Usage: package.sh [MAINTAINER="Name <mail>"]
set -euo pipefail
. "$(dirname "$0")/env.sh"

Q=/opt/qt5
SQ=$WORK/sysroot$Q
OUT=${OUT:-$WORK/deb}   # a test build goes elsewhere, e.g. OUT=$WORK/build/test-debs
VERSION=${VERSION:-5.15.19-9}
MAINTAINER=${MAINTAINER:-"Andrea Faggin <blackbird5308@gmail.com>"}
GENDIGSIGSUMS=$QT_SDK_PATH/Madde/madbin/gendigsigsums
IM_PLUGIN=plugins/platforminputcontexts/libmaliitplatforminputcontextplugin.so

rm -rf "${OUT:?}" && mkdir -p "$OUT"

# stage NAME: an empty staging tree for package NAME
stage() { mkdir -p "$OUT/stage/$1/DEBIAN" && echo "$OUT/stage/$1"; }

# build NAME SECTION DEPENDS DESCRIPTION: control, md5sums, digsigsums, then the .deb
build() {
    local name=$1 section=$2 depends=$3 description=$4 d=$OUT/stage/$1
    {
        echo "Package: $name"
        echo "Version: $VERSION"
        echo "Architecture: armel"
        echo "Maintainer: $MAINTAINER"
        echo "Installed-Size: $(du -sk --exclude=DEBIAN "$d" | cut -f1)"
        echo "Section: $section"
        echo "Priority: optional"
        [ -n "$depends" ] && echo "Depends: $depends"
        echo "Description: $description"
    } > "$d/DEBIAN/control"
    chmod -R go-w "$d"   # the box's umask (002) left group-writable directories
    (cd "$d" && find . -path ./DEBIAN -prune -o -type f -printf '%P\0' | xargs -0 md5sum) > "$d/DEBIAN/md5sums"
    perl "$GENDIGSIGSUMS" -o com.nokia.maemo "$OUT/digsigsums.tmp" "$d" 2>/dev/null
    mv "$OUT/digsigsums.tmp" "$d/DEBIAN/digsigsums"
    dpkg-deb --root-owner-group -Zgzip --build "$d" "$OUT/${name}_${VERSION}_armel.deb" >/dev/null
    echo "$(du -h "$OUT/${name}_${VERSION}_armel.deb" | cut -f1)  ${name}_${VERSION}_armel.deb ($(wc -l < "$d/DEBIAN/digsigsums") signed files)"
}

# copy SRC_SUBDIR DEST_STAGE [find args...]: copy files and symlinks below /opt/qt5/SRC_SUBDIR
copy() {
    local sub=$1 d=$2; shift 2
    (cd "$SQ" && find "$sub" \( -type f -o -type l \) "$@" -print0 | cpio -0 -pdm --quiet "$d$Q")
}

d=$(stage qt5-harmattan)
copy lib "$d" -name '*.so.*'
# Not the NetworkManager and ConnMan bearer plugins: Harmattan has neither, and they printed
# D-Bus errors ("propsReply ...") in every app using QNetworkAccessManager.
copy plugins "$d" -not -path "$IM_PLUGIN" -not -name libqnmbearer.so -not -name libqconnmanbearer.so
copy qml "$d" -not -path 'qml/com/*' -not -path 'qml/Qt/labs/components/*'
copy ssl "$d" \( -path 'ssl/certs/*' -o -name openssl.cnf \)   # OpenSSL's config, CA roots
# QtSensors' config (sensorfw as the default backend, and the sensors it registers): Qt 5's
# system settings directory, where both QSensorManager and the plugin read it.
install -D -m 644 "$WORK/sysroot/etc/xdg/QtProject/Sensors.conf" "$d/etc/xdg/QtProject/Sensors.conf"
build qt5-harmattan libs "" "Qt 5.15 runtime in /opt/qt5
 Qt 5.15 (KDE patch collection) for Qt Quick 2 apps on Harmattan, next to the system Qt 4:
 xcb with EGL on the SGX530, multitouch, orientation, the status bar and switcher, with
 OpenSSL 3.5 and current CA roots, sensors (through sensord), multimedia and the camera
 (GStreamer 0.10), haptics (meegofeedbackd), positioning (positioningd), Bluetooth (BlueZ 4),
 and the address book and media gallery (Tracker)."

d=$(stage qt5-meego-components)
copy qml "$d" \( -path 'qml/com/*' -o -path 'qml/Qt/labs/components/*' \)
build qt5-meego-components libs "qt5-harmattan (= $VERSION)" "Harmattan components (com.nokia.meego) for Qt 5
 The Qt Quick 2 port of the Harmattan Qt Components, drawn with the phone's blanco theme,
 with precompiled QML."

d=$(stage qt5-meego-inputcontext)
copy plugins "$d" -path "$IM_PLUGIN"
build qt5-meego-inputcontext libs "qt5-harmattan (= $VERSION)" "Stock keyboard for Qt 5 apps
 Maliit input context plugin speaking the phone's Maliit 0.81 protocol."

d=$(stage qt5-sample)
rm -rf "$WORK/build/sample-app" && mkdir -p "$WORK/build/sample-app" && cd "$WORK/build/sample-app"
"$WORK/host/bin/qmake" "$WORK/sample-app" >/dev/null
make -s -j6 >/dev/null 2>make.err || { cat make.err; exit 1; }
make -s install INSTALL_ROOT="$d" >/dev/null
install -D -m 644 "$WORK/sample-app/qt5-sample.desktop" "$d/usr/share/applications/qt5-sample.desktop"
install -D -m 644 "$WORK/sample-app/qt5-sample80.png" "$d/usr/share/icons/hicolor/80x80/apps/qt5-sample80.png"
build qt5-sample user/other "qt5-harmattan (= $VERSION), qt5-meego-components (= $VERSION), qt5-meego-inputcontext (= $VERSION)" "Qt 5 sample app
 A com.nokia.meego page on Qt 5, to check the qt5-harmattan packages."

rm -rf "$OUT/stage"
