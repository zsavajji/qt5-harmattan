# Phase 4 check: video with the GRP::video Aegis credential (zero-copy through gltexturesink).
TARGET = qt5-videotest
QT += quick
CONFIG += qtquickcompiler
SOURCES += main.cpp
RESOURCES += qml.qrc
target.path = /opt/qt5-videotest/bin
INSTALLS += target
