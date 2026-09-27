# GStreamer experiments inside a credentialed app (see gstprobe.cpp). Deploy qmldir and the
# library to <import path>/GstProbe on the phone.
TEMPLATE = lib
CONFIG += plugin link_pkgconfig
TARGET = gstprobe
QT += qml
PKGCONFIG += gstreamer-0.10 gstreamer-pbutils-0.10
SOURCES += gstprobe.cpp
