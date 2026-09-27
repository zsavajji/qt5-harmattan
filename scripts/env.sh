# Source on the box before any build step: . <checkout>/scripts/env.sh
# ssh runs a non-interactive zsh, which has no toolchain on PATH.
# WORK is this checkout (bash: BASH_SOURCE; zsh: $0 of a sourced file); the SDK is MADDE's.
# Both can be set beforehand. Qt's host qmake and CMake files find everything through WORK.
export WORK=${WORK:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)}
export QT_SDK_PATH=${QT_SDK_PATH:-$HOME/QtSDK}
export MADDE_SYSROOT=${MADDE_SYSROOT:-$QT_SDK_PATH/Madde/sysroots/harmattan_sysroot_10.2011.34-1_slim}
export TOOLCHAIN_PREFIX=arm-none-linux-gnueabi
# GCC 14 from harmattan-toolchain (scripts/build-toolchain.sh), not the Nokia SDK's GCC 4.4.
export PATH="$WORK/cross/bin:$PATH"
# pkg-config sees our /opt/qt5 first, then the SDK's libraries. Without these, qmake (built
# with -sysroot) looks only in <sysroot>/usr/lib/pkgconfig and apps using PKGCONFIG for
# xcb or xkbcommon fail with "Project ERROR: xcb development package not found".
export PKG_CONFIG_SYSROOT_DIR=$WORK/sysroot
export PKG_CONFIG_LIBDIR=$WORK/sysroot/opt/qt5/lib/pkgconfig:$WORK/sysroot/opt/qt5/share/pkgconfig:$WORK/sysroot/usr/lib/pkgconfig:$WORK/sysroot/usr/share/pkgconfig
