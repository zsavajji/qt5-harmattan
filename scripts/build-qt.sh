#!/usr/bin/env bash
# Phase 2.2: configure and build qtbase, then qtdeclarative and qtsvg (and later phases'
# modules). Target files go to /opt/qt5 staged in $WORK/sysroot, host tools (qmake, moc, ...)
# to $WORK/host.
# Usage: build-qt.sh [step...]  steps: configure qtbase qtdeclarative qtsvg qtinsider-maliit
#        qt-components sensorfw qtsensors qtmultimedia qtgraphicaleffects qtimageformats
#        qtwebsockets qtquickcontrols2 qtfeedback qtlocation qtconnectivity (default: all of
#        them, in that order);
#        relocate (also run by each)
# Re-runnable: finished steps leave a stamp in $B; delete the stamp to redo a step.
set -euo pipefail
. "$(dirname "$0")/env.sh"

SR=$WORK/sysroot
SRC=$WORK/src
B=$WORK/build
Q=/opt/qt5
export PKG_CONFIG_SYSROOT_DIR=$SR
export PKG_CONFIG_LIBDIR=$SR$Q/lib/pkgconfig:$SR$Q/share/pkgconfig:$SR/usr/lib/pkgconfig:$SR/usr/share/pkgconfig
unset PKG_CONFIG_PATH

done_() { [ -f "$B/$1.done" ]; }
stamp() { touch "$B/$1.done"; echo "== $1 done"; }

configure() {
    done_ configure && return
    apply_patches qtbase
    # configure finds -xplatform specs only inside qtbase/mkspecs.
    rsync -a --delete "$WORK/mkspecs/linux-harmattan-g++/" "$SRC/qtbase/mkspecs/linux-harmattan-g++/"
    rm -rf "$B/qtbase" && mkdir -p "$B/qtbase" && cd "$B/qtbase"
    "$SRC/qtbase/configure" -prefix $Q -sysroot "$SR" -hostprefix "$WORK/host" \
        -xplatform linux-harmattan-g++ -release -opensource -confirm-license -c++std c++17 \
        -nomake examples -nomake tests -pkg-config \
        -opengl es2 -egl -xcb -qpa xcb -no-eglfs -no-linuxfb -no-kms -no-gbm \
        -no-icu -system-freetype -fontconfig -qt-harfbuzz -qt-pcre -qt-libpng -qt-libjpeg \
        -dbus-linked -no-feature-threadsafe-cloexec \
        -openssl-linked OPENSSL_PREFIX="$SR$Q"
    # OPENSSL_PREFIX: configure doesn't ask pkg-config for OpenSSL, and the SDK sysroot's
    # /usr/include has the phone's 0.9.8 headers. Ours are from scripts/build-deps.sh.
    stamp configure
}

apply_patches() { # patches/<module>/*.patch onto the source checkout, each once
    for p in "$WORK/patches/$1"/*.patch; do
        [ -f "$p" ] || continue
        # "if", not "&&": an already applied patch must not end the loop with status 1 (set -e).
        if patch -d "$SRC/$1" -p1 -N -s --dry-run < "$p" >/dev/null; then patch -d "$SRC/$1" -p1 -N -s < "$p"; fi
    done
}

module() { # qtbase uses the configured tree above; the others go through our qmake
    local n=$1
    done_ "$n" && return
    apply_patches "$n"
    if [ "$n" = qt-components ]; then
        # com.nokia.meego (3.3): its own configure finds qmake on PATH. Local theme: images are
        # read from /usr/share/themes/blanco, not from the Qt 4 theme daemon.
        rm -rf "${B:?}/$n" && mkdir -p "$B/$n" && cd "$B/$n"
        PATH="$WORK/host/bin:$PATH" "$SRC/$n/configure" -meego -force-local-theme -nomake examples -nomake tests
    elif [ "$n" = qtmultimedia ]; then
        # Phase 4: the phone's GStreamer 0.10 (playbin2, the DSP decoders, pulsesink).
        rm -rf "${B:?}/$n" && mkdir -p "$B/$n" && cd "$B/$n"
        "$WORK/host/bin/qmake" "$SRC/$n" -- -gstreamer 0.10
    elif [ "$n" = qtfeedback ]; then
        # Haptics: the library, the QML import and the meegotouch backend (meegofeedbackd),
        # not the examples; FileEffect's multimedia backend needs a module build (none here).
        rm -rf "${B:?}/$n" && mkdir -p "$B/$n" && cd "$B/$n"
        "$WORK/host/bin/qmake" "$SRC/$n/src" meegotouchfeedback_enabled=yes multimedia_disabled=yes
    elif [ "$n" != qtbase ]; then
        rm -rf "${B:?}/$n" && mkdir -p "$B/$n" && cd "$B/$n"
        "$WORK/host/bin/qmake" "$SRC/$n"
    fi
    cd "$B/$n"
    make -j6
    make install
    [ "$n" = qt-components ] && precompile_qml "$SR$Q/qml/com/nokia/meego" "$SR$Q/qml/com/meego"
    relocate
    stamp "$n"
}

# Phase 4: sensorfw's Qt 5 client (libsensorclient-qt5, libsensordatatypes-qt5), which
# qtsensors' sensorfw plugin finds as pkg-config sensord-qt5. Only these two parts of
# sensorfw; patches/sensorfw makes them speak the phone's sensord 0.6.46.
sensorfw() {
    done_ sensorfw && return
    apply_patches sensorfw
    local d
    rm -rf "${B:?}/sensorfw"
    for d in datatypes qt-api; do   # siblings: qt-api links -L../datatypes
        mkdir -p "$B/sensorfw/$d" && cd "$B/sensorfw/$d"
        "$WORK/host/bin/qmake" "$SRC/sensorfw/$d/$d.pro"
        make -j6
        make install
    done
    # The top-level project, not built here, installs these and the .pc file.
    cp "$SRC"/sensorfw/include/*.h "$SR$Q/include/sensord-qt5/"
    cat > "$SR$Q/lib/pkgconfig/sensord-qt5.pc" <<EOF
prefix=$Q
includedir=\${prefix}/include/sensord-qt5
libdir=\${prefix}/lib

Name: Sensorfw-qt5
Description: Sensord client for Qt 5 (sensorfw 0.15.2, Harmattan protocol)
Version: 0.15.2
Libs: -L\${libdir} -lsensorclient-qt5 -lsensordatatypes-qt5
Cflags: -I\${includedir} -I\${includedir}/datatypes
EOF
    relocate
    stamp sensorfw
}

# 5.1: no absolute paths of this checkout in the SDK, so it works wherever WORK (env.sh) points.
# - Host qmake reads its paths from host/bin/qt.conf, which takes them from $(WORK).
# - Installed .pri/.prl files use qmake's $$[QT_SYSROOT] and $$[QT_HOST_PREFIX], CMake files
#   $ENV{WORK}, .pc files /opt/qt5 (pkg-config adds the sysroot) and the sysroot for host tools.
# - Build-dir references (QMAKE_PRL_BUILD_DIR, #line in generated headers) and libtool .la files
#   go. Runs after every install, as make install writes the absolute paths again.
relocate() {
    # The three groups reproduce the built-in -query exactly: Qt's own .prf files read
    # $$[QT_INSTALL_QML/get] and friends (qmake prefixes the sysroot) and $$[.../src].
    cat > "$WORK/host/bin/qt.conf" <<'EOF'
[Paths]
Prefix=/opt/qt5
Settings=etc/xdg
Sysroot=$(WORK)/sysroot
SysrootifyPrefix=true
HostPrefix=$(WORK)/host
TargetSpec=linux-harmattan-g++
HostSpec=linux-g++

[EffectivePaths]
Prefix=/opt/qt5
Settings=etc/xdg
HostPrefix=$(WORK)/host

[EffectiveSourcePaths]
Prefix=/opt/qt5
Settings=etc/xdg
HostPrefix=$(WORK)/host
EOF
    local f
    { grep -rlIZ --fixed-strings "$WORK/" "$SR$Q" "$WORK/host" || true; } | while IFS= read -r -d '' f; do
        case $f in
        *.pri|*.prl) P=$WORK perl -ni -e 'next if /^QMAKE_PRL_BUILD_DIR/;
            s/\Q$ENV{P}\E\/sysroot/\$\$[QT_SYSROOT]/g; s/\Q$ENV{P}\E\/host/\$\$[QT_HOST_PREFIX]/g; print' "$f" ;;
        *.cmake) P=$WORK perl -pi -e 's/\Q$ENV{P}\E\//\$ENV{WORK}\//g' "$f" ;;
        *.pc) P=$WORK perl -pi -e 's/\Q$ENV{P}\E\/host/\${pc_sysrootdir}\/..\/host/g; s/\Q$ENV{P}\E\/sysroot//g' "$f" ;;
        *.h) P=$WORK perl -pi -e 's/^(#line \d+ ")\Q$ENV{P}\E\//$1/' "$f" ;;
        *.la) rm "$f" ;;
        esac
    done
}

# 3.5: ahead-of-time cache files (file.qmlc, file.jsc) next to the installed sources. Qt 5.15
# reads them before compiling on first start (and fsyncing the result into ~/.cache): a cold
# com.nokia.meego page took 6-7.5 s instead of 1.9 s. A .qmlc holds its source's mtime in ms and
# tar (so .debs) keeps whole seconds, so the sources' mtimes are rounded down first.
precompile_qml() {
    find "$@" \( -name '*.qml' -o -name '*.js' \) | while read -r f; do
        touch -d "@$(stat -c %Y "$f")" "$f"
        "$WORK/host/bin/qmlcachegen" "$f" -o "${f}c"
    done
}

for step in ${*:-configure qtbase qtdeclarative qtsvg qtinsider-maliit qt-components sensorfw qtsensors qtmultimedia \
                qtgraphicaleffects qtimageformats qtwebsockets qtquickcontrols2 qtfeedback qtlocation qtconnectivity}; do
    case $step in
        configure) configure ;;
        relocate) relocate ;;
        sensorfw) sensorfw ;;
        *) module "$step" ;;
    esac
done
