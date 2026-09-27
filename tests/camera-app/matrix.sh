# On the phone: camera test matrix for the installed qt5-cameratest (no dev tree, no preload).
#   sh matrix.sh <runs> <case>...   cases below; results in /home/user/qt5tests/matrix/
# Each run: a clean environment, 15 s, then one line: case, run, status sequence, errors,
# viewfinder sink, Qt libraries mapped from outside /opt/qt5 (should be none), screenshot.
# Camera statuses: 2 loading, 4 loaded, 6 starting, 8 active.
T=/home/user/qt5tests
M=$T/matrix
mkdir -p $M
. /tmp/session_bus_address.user
NOKIA="QT_GSTREAMER_CAMERABIN_SRC=camsrcbin QT_GSTREAMER_CAMERABIN_VIDEOSRC=subdevsrc2"

runs=$1; shift
for c in "$@"; do
    qml=""; e=""
    case $c in
        default)    ;;                                                    # Qt's own choice (subdevsrc)
        novf)       e="$NOKIA"; qml=$T/novf.qml ;;                     # no VideoOutput: fakesink
        vf)         e="$NOKIA" ;;                                         # built-in page, VideoOutput
        vf-copy)    e="$NOKIA CAMEXP_NOTEXSINK=1" ;;                      # Qt's copying sink only
        vf-fb0)     e="$NOKIA CAMEXP_FBMEM=0" ;;                          # gltexturesink, no fb memory
        vf-mode)    e="$NOKIA CAMEXP_NOMODE=1" ;;                         # gltexturesink, default mode
        vf-mode-fb0) e="$NOKIA CAMEXP_NOMODE=1 CAMEXP_FBMEM=0" ;;
        vf-v1)      e="QT_GSTREAMER_CAMERABIN_SRC=camsrcbin QT_GSTREAMER_CAMERABIN_VIDEOSRC=subdevsrc" ;;
        *) echo "unknown case $c"; continue ;;
    esac
    i=1
    while [ $i -le $runs ]; do
        for p in $(pgrep qt5-cameratest); do kill -9 $p; done
        sleep 2
        log=$M/$c-$i.log
        env -i DBUS_SESSION_BUS_ADDRESS=$DBUS_SESSION_BUS_ADDRESS DISPLAY=:0 HOME=/home/user \
            PATH=/usr/bin:/bin TMPDIR=/var/tmp USER=user $e \
            /opt/qt5-cameratest/bin/qt5-cameratest $qml > $log 2>&1 &
        sleep 15
        p=$(pgrep qt5-cameratest)
        foreign=$( [ -n "$p" ] && grep -E 'libQt5|/plugins/' /proc/$p/maps | awk '{print $6}' | sort -u | grep -v '^/opt/qt5/' | tr '\n' ' ')
        DISPLAY=:0 /home/user/n9shot > $M/$c-$i.ppm
        [ -n "$p" ] && kill -9 $p
        seq=$(grep 'qml: camera status' $log | awk '{print $4}' | tr '\n' ' ')
        err=$(grep -E 'CameraBin error|qml: camera error' $log | head -1 | cut -c1-80)
        sink=$(grep 'CAMEXP viewfinder sink' $log | awk '{print $4}' | tr '\n' ' ')
        tex=$(grep 'CAMEXP gltexturesink' $log | head -1 | cut -d' ' -f3-)
        echo "$c | $i | ${p:+alive} | $seq| $err | $sink| $tex | ${foreign:-clean}"
        i=$((i + 1))
    done
done
