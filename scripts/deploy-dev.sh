#!/usr/bin/env bash
# Copy the staged Qt (bin, lib, plugins, qml, CA certificates) into the phone's dev tree
# /home/user/qt5. Always all of it: patching a Qt header changes class layouts, and a plugin
# built against the old layout next to a new library misbehaves (2.3: QXcbEglWindow saw
# m_window == 0). Run it on the build box, or on another machine with BOX (the build box's ssh
# target) and BOX_WORK (its checkout, relative to its home or absolute) set: the tree then
# streams through that machine. PHONE: the phone's ssh target (default n9).
set -euo pipefail
PHONE=${PHONE:-n9}
if [ -n "${BOX:-}" ]; then
    ssh "$BOX" "tar -C ${BOX_WORK:-projects/qt5-harmattan}/sysroot/opt/qt5 -c \
        --exclude=lib/pkgconfig --exclude=lib/cmake --exclude='*.prl' --exclude='*.a' --exclude='*.la' \
        bin lib plugins qml ssl/certs" </dev/null
else
    . "$(dirname "$0")/env.sh"
    tar -C "$WORK/sysroot/opt/qt5" -c \
        --exclude=lib/pkgconfig --exclude=lib/cmake --exclude='*.prl' --exclude='*.a' --exclude='*.la' \
        bin lib plugins qml ssl/certs
fi | ssh "$PHONE" 'mkdir -p /home/user/qt5 && tar -C /home/user/qt5 -x'
# Wait for the writes to reach flash (about 35 s): otherwise the next app start stalls behind
# them, which looked like a 25-30 s QML startup (3.5).
ssh "$PHONE" 'sync; du -sh /home/user/qt5'
