# Qt 5 for Harmattan

Qt 5.15 (KDE's patch collection) for Qt Quick 2 apps on the Nokia N9 and N950, on stock
Harmattan PR1.3. It installs under `/opt/qt5` next to the system Qt 4 and needs no changes to
the phone. Apps render on the SGX530 GPU, type with the stock keyboard, rotate, take
multitouch, show the status bar, minimize to the switcher, and look native through a Qt 5
port of the Harmattan components (`com.nokia.meego`).

Beyond Qt Quick: TLS (OpenSSL 3.5, current CA roots), sensors, multimedia with the camera and
hardware video decoding, graphical effects, Quick Controls 2, WebSockets, haptics,
positioning and Bluetooth. The module list with what works on the phone is in
[docs/developing.md](docs/developing.md).

Built and ported with Claude Opus 5.5

## Use it

Each [release](../../releases) has:

- `qt5-harmattan-sdk-<version>-linux-x86_64.tar.xz`: the SDK for a Linux x86-64 PC: the GCC 14
  cross compiler, Qt's host tools, a CMake toolchain file, a sample app, the phone packages,
  and the guide. You also need Nokia's Qt SDK 1.2.1 with the Harmattan target (MADDE): the
  phone's own headers and libraries come from it and aren't redistributed here.
- the phone packages (`qt5-harmattan`, `qt5-meego-components`, `qt5-meego-inputcontext`,
  `qt5-sample`), also inside the SDK;
- `qt5-harmattan-sources-<version>.tar`: the exact sources the binaries are built from.

[docs/developing.md](docs/developing.md) walks through installing the SDK and the runtime,
and building, running and packaging an app.

## Build it from source

On a Linux x86-64 box with Nokia's Qt SDK 1.2.1 (Harmattan target) in `~/QtSDK` (or
`QT_SDK_PATH` set), git, perl, python3, pkg-config, flex, bison, gperf, meson, ninja, cmake,
rsync and curl, and [harmattan-toolchain](../../../harmattan-toolchain) cloned next to this
checkout (or `HARMATTAN_TOOLCHAIN` set):

```sh
. scripts/env.sh                # WORK is this checkout; run it in every shell
scripts/fetch-sources.sh        # upstream sources at their pinned commits, into src/
scripts/build-toolchain.sh      # GCC 14 into cross/, the sysroot copy into sysroot/
scripts/build-deps.sh           # xcb, xkbcommon, the C++ runtime, OpenSSL into sysroot/opt/qt5
scripts/build-qt.sh             # configure, patch and build every module
scripts/package.sh              # phone packages into deb/
scripts/package-sdk.sh          # the SDK tarball into deb/
scripts/package-sources.sh      # the source tarball into deb/
```

Every step can be re-run; finished steps leave a stamp in `build/`. `scripts/check-patches.sh`
checks that each patch series applies to its pristine source and reproduces `src/`.

## Layout

| Path | What |
|---|---|
| `patches/<module>/` | our changes to each upstream module, one `diff -u` per change with a header saying why |
| `mkspecs/linux-harmattan-g++/` | the qmake target spec |
| `cmake/` | the CMake toolchain file for Qt 5 apps |
| `scripts/` | fetching, building, packaging, and small tools for the phone |
| `sample-app/`, `tests/` | the sample app and the checks run on the phone |
| `docs/developing.md` | the app developer's guide (also the SDK's README) |
| `SPECS.md` | why things are done the way they are |

## Licences

Our scripts, mkspec, CMake files and docs: MIT (`LICENSE`). Each patch is under the licence of
the module it changes: Qt's modules are LGPL 3 / GPL 2 or 3, the Harmattan components BSD,
the Maliit input context, sensorfw and qtfeedback LGPL 2.1. The binaries also contain OpenSSL
(Apache 2.0), libxcb and xkbcommon (MIT), and GCC's C++ runtime (GPL 3 with the Runtime
Library Exception). Nokia's
SDK and the phone's own software are Nokia's and aren't part of this project.

## Thanks

This builds on other people's work:

- **The Qt Company and the Qt Project** for Qt, and **KDE** for the Qt 5.15 patch collection
  built here.
- **Nokia**, who made Harmattan and wrote the originals of much of this: the Harmattan
  components (`com.nokia.meego`) with their in-app status bar, Maliit, sensorfw, and Qt
  Mobility, whose Harmattan backends for positioning, video and haptics showed how to talk to
  the phone. Qt 5.0–5.3's Harmattan multitouch code (Digia) is the model for ours.
- **Nemo Mobile**, for porting the Harmattan components to Qt Quick 2.
- **qtinsider**, for the Maliit input context for the N9 used here, and an earlier xcb platform
  plugin for the N9 that served as a reference.
- **Jolla and Sailfish OS**, who keep sensorfw and qtfeedback alive.
- The libxcb and xkbcommon developers, the OpenSSL project, and Mozilla's CA programme (through
  curl's extract of its roots).
