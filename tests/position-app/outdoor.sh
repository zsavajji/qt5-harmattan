#!/bin/sh
# Outdoor A-GPS run (no ssh needed): the installed qt5-positiontest with timestamps, plus a
# sampler: SUPL connections (port 7275/7276), network interfaces and routes, the positioning
# daemons. Stops after $1 minutes (default 90) or when the app is closed.
T=/home/user/qt5tests; L=$T/outdoor-$(date +%m%d-%H%M)
mkdir -p $L
. /tmp/session_bus_address.user
{ date; cat /etc/xdg/nokia/location-settings.conf; echo "positioningd $(pidof positioningd) nped $(pidof nped)"; } > $L/start.txt
env -i DBUS_SESSION_BUS_ADDRESS=$DBUS_SESSION_BUS_ADDRESS DISPLAY=:0 HOME=/home/user PATH=/usr/bin:/bin \
    TMPDIR=/var/tmp USER=user QT_LOGGING_RULES="qt.positioning.*=true" \
    QT_MESSAGE_PATTERN="%{time hh:mm:ss.zzz} %{message}" \
    /opt/qt5-positiontest/bin/qt5-positiontest > $L/app.log 2>&1 &
app=$!
echo "$(date +%T) app $app" >> $L/start.txt
end=$(( $(date +%s) + ${1:-90} * 60 )); n=0
while [ $(date +%s) -lt $end ] && kill -0 $app 2>/dev/null; do
    c=$(cat /proc/net/tcp /proc/net/tcp6 2>/dev/null | awk '$3 ~ /:1C73$|:1C74$/ {print $3, $4}' | tr '\n' ' ')
    [ -n "$c" ] && echo "$(date +%T) $c" >> $L/supl.log
    if [ $((n % 15)) = 0 ]; then
        { echo "== $(date +%T) positioningd $(pidof positioningd) nped $(pidof nped)"
          awk '$2 == "00000000" {print "default via", $1}' /proc/net/route
          awk -F'[: ]+' 'NR > 2 && $3 > 0 {print $2, "rx", $3, "tx", $11}' /proc/net/dev; } >> $L/net.log
    fi
    n=$((n + 1)); sleep 2
done
kill $app 2>/dev/null
echo "$(date +%T) stopped" >> $L/start.txt
