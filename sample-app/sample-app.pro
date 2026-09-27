# 5.1: the sample app, packaged by scripts/package.sh to check the runtime .debs from the
# app grid. QML is compiled in (qtquickcompiler), so its first start doesn't compile it.
TEMPLATE = app
TARGET = qt5-sample
QT += quick
CONFIG += qtquickcompiler
SOURCES += main.cpp
RESOURCES += qml.qrc
target.path = /opt/qt5-sample/bin
INSTALLS += target
