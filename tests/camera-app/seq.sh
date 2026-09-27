# On the phone: sequence.qml in qt5-cameratest (dev: the dev-tree build), a screenshot per
# "SHOT <name>" line, killed at "SEQUENCE END" or after LIMIT seconds (default 200).
#   sh seq.sh <tag> [dev] [VAR=value...] [-- sequence.qml arguments]
# Log and shots in /home/user/qt5tests/seq-<tag>*.
T=/home/user/qt5tests; tag=$1; shift
bin=/opt/qt5-cameratest/bin/qt5-cameratest
[ "$1" = dev ] && { bin=/opt/qt5-cameratest/dev/bin/qt5-cameratest-dev; shift; }
vars=""; while [ $# -gt 0 ] && [ "$1" != -- ]; do vars="$vars $1"; shift; done; [ "$1" = -- ] && shift
. /tmp/session_bus_address.user
for p in $(pgrep qt5-cameratest); do kill -9 $p; done; sleep 2
rm -f $T/seq-$tag*
log=$T/seq-$tag.log
env -i DBUS_SESSION_BUS_ADDRESS=$DBUS_SESSION_BUS_ADDRESS DISPLAY=:0 HOME=/home/user PATH=/usr/bin:/bin \
    TMPDIR=/var/tmp USER=user $vars $bin $T/sequence.qml "$@" 2>&1 \
    | awk '/still in use/ {n++; next} {print; fflush()} END {print "[still-in-use " n+0 "]"}' > $log &
i=0
app=$!   # the log's awk, which ends with the app
while [ $i -lt ${LIMIT:-200} ] && kill -0 $app 2>/dev/null && ! grep -q 'SEQUENCE END' $log; do
    for n in $(grep -o 'SHOT [a-z0-9-]*' $log | awk '{print $2}'); do
        [ -f $T/seq-$tag-$n.ppm ] || DISPLAY=:0 /home/user/n9shot > $T/seq-$tag-$n.ppm
    done
    sleep 1; i=$((i + 1))
done
for p in $(pgrep qt5-cameratest); do kill -9 $p; done; sleep 1
grep -E 'STEP|SEQUENCE|error|failed|saved' $log
