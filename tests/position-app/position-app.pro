# Phase 4 check: positions from positioningd (the positioningd position plugin) with the
# Location Aegis credential.
TARGET = qt5-positiontest
QT += quick positioning
CONFIG += qtquickcompiler
SOURCES += main.cpp
RESOURCES += qml.qrc
target.path = /opt/qt5-positiontest/bin
INSTALLS += target

dev {
    # qt5-positiontest-dev: the same app, loading Qt from the phone's dev tree (/home/user/qt5,
    # scripts/deploy-dev.sh) before /opt/qt5, with a qt.conf there for plugins and QML: the
    # plugin is tried with the Location credential without installing packages.
    TARGET = qt5-positiontest-dev
    QMAKE_LFLAGS = -Wl,-rpath,/home/user/qt5/lib $$QMAKE_LFLAGS
    target.path = /opt/qt5-positiontest/dev/bin
}
