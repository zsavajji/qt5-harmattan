# On the phone: one camera run of the installed qt5-cameratest (Nokia's source), 12 s, killed.
#   sh run1.sh <tag> <qml or ""> [VAR=value...]   log in /home/user/qt5tests/run-<tag>.log
# "still in use" lines (libomap3camd's retry loop) are counted, not kept: they fill /home.
T=/home/user/qt5tests; tag=$1; qml=$2; shift 2
. /tmp/session_bus_address.user
for p in $(pgrep qt5-cameratest); do kill -9 $p; done; sleep 2
echo "== $(date +%T) $tag $*"
env -i DBUS_SESSION_BUS_ADDRESS=$DBUS_SESSION_BUS_ADDRESS DISPLAY=:0 HOME=/home/user PATH=/usr/bin:/bin \
    TMPDIR=/var/tmp USER=user QT_GSTREAMER_CAMERABIN_SRC=camsrcbin QT_GSTREAMER_CAMERABIN_VIDEOSRC=subdevsrc2 "$@" \
    /opt/qt5-cameratest/bin/qt5-cameratest $qml 2>&1 \
    | awk '/still in use/ {n++; next} {print; fflush()} END {print "[still-in-use " n+0 "]"}' > $T/run-$tag.log &
sleep 12
for p in $(pgrep qt5-cameratest); do kill -9 $p; done; sleep 1
echo "   statuses: $(grep 'camera status' $T/run-$tag.log | awk '{print $4}' | tr '\n' ' ')$(tail -1 $T/run-$tag.log)"
grep -E 'CAMEXP (load|READY -> PAUSED)' $T/run-$tag.log | sed 's/^/   /'
