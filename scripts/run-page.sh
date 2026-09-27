# On the phone: run a QML page in the grid's environment, for side-by-side checks (3.3).
#   sh run-page.sh 4 page4.qml   stock Qt 4 components (/home/user/qml4view, scripts/qml4view.cpp)
#   sh run-page.sh 5 page.qml    Qt 5 (the dev tree's qmlscene with the installed runtime)
# QT5ENV adds variables for Qt 5 (e.g. QML2_IMPORT_PATH=/home/user/qt5/qml for dev-tree
# components). Output goes to /home/user/qt5tests/run.log.
. /tmp/session_bus_address.user
E="DBUS_SESSION_BUS_ADDRESS=$DBUS_SESSION_BUS_ADDRESS DISPLAY=:0 HOME=/home/user LANG=it PATH=/usr/bin:/bin QT_IM_MODULE=MInputContext TMPDIR=/var/tmp USER=user XDG_CACHE_HOME=/home/user/.cache XDG_DATA_HOME=/home/user/.local/share/"
if [ "$1" = 4 ]; then
    env -i $E /home/user/qml4view "$2" > /home/user/qt5tests/run.log 2>&1 &
else
    env -i $E $QT5ENV /home/user/qt5/bin/qmlscene --fullscreen "$2" > /home/user/qt5tests/run.log 2>&1 &
fi
