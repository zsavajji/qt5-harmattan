# Phase 4 check: the camera (camerabin plugin, Nokia's subdevsrc) with the GRP::video credential.
TARGET = qt5-cameratest
QT += quick
CONFIG += qtquickcompiler
SOURCES += main.cpp
RESOURCES += qml.qrc
target.path = /opt/qt5-cameratest/bin
INSTALLS += target

dev {
    # qt5-cameratest-dev: the same app, loading Qt from the phone's dev tree (/home/user/qt5,
    # scripts/deploy-dev.sh) before /opt/qt5, with a qt.conf there for plugins and QML: Qt
    # library changes are tried with GRP::video without installing packages.
    TARGET = qt5-cameratest-dev
    QMAKE_LFLAGS = -Wl,-rpath,/home/user/qt5/lib $$QMAKE_LFLAGS
    target.path = /opt/qt5-cameratest/dev/bin
}
