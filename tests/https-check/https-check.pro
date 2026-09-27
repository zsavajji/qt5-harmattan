# Phase 4 check: HTTPS through QtNetwork and OpenSSL, with the CA roots Qt ships.
#   https-check https://example.com https://api.github.com ...
QT = core network
CONFIG += console
SOURCES = main.cpp
