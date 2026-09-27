# 2.3 go/no-go test app. Build: <WORK>/host/bin/qmake && make
QT += quick gui-private
# xcb: the client-message trace in main.cpp (3.2 diagnostics).
CONFIG += link_pkgconfig
PKGCONFIG += xcb
CONFIG += c++17
SOURCES += main.cpp
RESOURCES += qml.qrc
