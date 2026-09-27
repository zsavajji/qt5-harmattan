# CMake toolchain for Qt 5 apps on the N9 (5.1). For the build box, where scripts/env.sh sets
# WORK (see docs/developing.md):
#
#   . <checkout>/scripts/env.sh
#   cmake -S myapp -B build -DCMAKE_TOOLCHAIN_FILE=$WORK/cmake/harmattan-qt5.cmake
#   cmake --build build
#
# find_package(Qt5) finds /opt/qt5 in $WORK/sysroot; Qt's CMake files run moc, rcc and
# qmlcachegen from $WORK/host/bin. Flags as in mkspecs/linux-harmattan-g++.

set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR arm)

if(NOT DEFINED ENV{WORK})
    message(FATAL_ERROR "WORK is not set: source scripts/env.sh first.")
endif()
set(HARMATTAN_WORK "$ENV{WORK}")

# Our GCC 14 (scripts/build-toolchain.sh), not the SDK's GCC 4.4.
set(CMAKE_C_COMPILER   "${HARMATTAN_WORK}/cross/bin/arm-none-linux-gnueabi-gcc")
set(CMAKE_CXX_COMPILER "${HARMATTAN_WORK}/cross/bin/arm-none-linux-gnueabi-g++")

set(CMAKE_SYSROOT "${HARMATTAN_WORK}/sysroot")
set(CMAKE_FIND_ROOT_PATH "${HARMATTAN_WORK}/sysroot")
list(APPEND CMAKE_PREFIX_PATH /opt/qt5) # searched inside the sysroot

# Cortex-A8 with NEON, hard float as the system libc. SUPPORT_X11: the SGX EGL headers use the
# X11 native types only with it.
set(CMAKE_C_FLAGS_INIT "-march=armv7-a -mtune=cortex-a8 -mfpu=neon -mfloat-abi=hard -mthumb -DSUPPORT_X11")
set(CMAKE_CXX_FLAGS_INIT "${CMAKE_C_FLAGS_INIT}")

# DT_RPATH /opt/qt5/lib (not RUNPATH: it also covers libraries loaded by libraries, so our
# libstdc++ and libxcb win over the system's), in the build tree too: CMake's own build rpath
# is padded with ':' for the install-time rewrite, and an empty entry means the current
# directory. And the rootfs's loader name.
set(CMAKE_BUILD_WITH_INSTALL_RPATH ON)
set(CMAKE_INSTALL_RPATH /opt/qt5/lib)
set(CMAKE_EXE_LINKER_FLAGS_INIT "-Wl,--disable-new-dtags -Wl,--dynamic-linker,/lib/ld-linux.so.3")
set(CMAKE_SHARED_LINKER_FLAGS_INIT "-Wl,--disable-new-dtags")
set(CMAKE_MODULE_LINKER_FLAGS_INIT "-Wl,--disable-new-dtags")

# Programs (moc, rcc, the compiler) are host binaries; headers, libraries and packages come
# from the sysroot.
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
