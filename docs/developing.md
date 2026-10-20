# Qt 5 SDK for the Nokia N9 / N950

Qt 5.15 for Qt Quick 2 apps on stock Harmattan PR1.3. It installs on the phone under
`/opt/qt5`, next to the system Qt 4, with the Harmattan components (`com.nokia.meego`), the
stock keyboard, rotation, multitouch and the status bar. This guide covers setting up the
SDK on a Linux PC, putting the Qt 5 runtime on the phone, and building, running and
packaging an app. `sample-app/` is a complete example.

## 1. What you need

- **A Linux x86-64 PC** with glibc 2.43 or newer (the SDK is built on Ubuntu 26.04), and
  `make`, `rsync`, `perl`, `xz`, `dpkg-deb` (1.19 or newer). For CMake builds, `cmake` 3.16
  or newer.
- **The Qt SDK 1.2.1 with the Harmattan target (MADDE)**, in `~/QtSDK`. The SDK takes the
  phone's libraries and headers from its sysroot
  (`Madde/sysroots/harmattan_sysroot_10.2011.34-1_slim`), and `gendigsigsums` for packages.
  If it lives elsewhere, set `QT_SDK_PATH` (or `MADDE_SYSROOT` for the sysroot itself).
- **An N9 or N950 on PR1.3 in developer mode** (Settings → Security → Developer mode). You
  need root on it (`devel-su` in the Terminal) to install packages.

## 2. Install the SDK

```sh
tar xJf qt5-harmattan-sdk-<version>-linux-x86_64.tar.xz
qt5-harmattan-sdk-<version>-linux-x86_64/scripts/setup-sysroot.sh
```

`setup-sysroot.sh` builds `sysroot/`: MADDE's sysroot with Qt 5 in `/opt/qt5` and a few
header fixes on top, about 1.2 GB. Run it again if MADDE moves. The SDK can live anywhere
and can be moved later: it finds everything through `WORK`, which `env.sh` sets. So in
every shell you build from, first run:

```sh
. <sdk>/scripts/env.sh   # WORK, the cross compiler on PATH, pkg-config
```

## 3. Install the Qt 5 runtime on the phone

The packages are in the SDK's `phone/` directory:

| Package | What it is |
|---|---|
| `qt5-harmattan` | Qt 5.15 in `/opt/qt5` (22 MB), with the modules in step 4 |
| `qt5-meego-components` | `com.nokia.meego`, precompiled |
| `qt5-meego-inputcontext` | the stock keyboard for Qt 5 apps |
| `qt5-sample` | a sample app, to check the others (optional) |

1. Copy them to the phone, over USB mass storage into `MyDocs` or with scp:
   ```sh
   ssh user@<phone> mkdir -p /home/user/MyDocs/qt5-debs
   scp <sdk>/phone/*.deb user@<phone>:/home/user/MyDocs/qt5-debs/
   ```
2. On the phone, in the Terminal (or over ssh), become root and install all of them in one
   go, so dpkg orders them itself:
   ```sh
   devel-su                                   # the password is rootme
   dpkg -i /home/user/MyDocs/qt5-debs/*.deb
   ```
3. Check: `dpkg -l 'qt5-*'` lists them as `ii`, and **Qt 5 Sample** (a green icon) is in
   the app grid. It should open full screen with the status bar, type with the keyboard,
   rotate, and swipe away to the switcher like any other app.

To upgrade, `dpkg -i` the new versions the same way. To remove everything:
`dpkg -r qt5-sample qt5-meego-inputcontext qt5-meego-components qt5-harmattan`.

## 4. Write an app

- Import `com.nokia.meego 2.0`: the Qt 4 components' API, on Qt Quick 2. Use a
  `PageStackWindow` as the root.
- Show the view full screen: Harmattan apps own the whole screen, and `PageStackWindow`
  draws the status bar.

  ```cpp
  #include <QGuiApplication>
  #include <QQuickView>

  int main(int argc, char **argv)
  {
      QGuiApplication app(argc, argv);
      QQuickView view;
      view.setSource(QUrl(QStringLiteral("qrc:/main.qml")));
      view.showFullScreen();
      return app.exec();
  }
  ```
- Compile the QML into the binary (below). Otherwise Qt compiles it on the app's first
  start and writes the result to flash, which takes seconds on the phone.

Beyond Qt Quick, the runtime has:

| Module | qmake / QML | On the phone |
|---|---|---|
| Qt Network with TLS | `QT += network` | OpenSSL 3.5, TLS 1.3. Certificates are checked against current Mozilla roots shipped in `/opt/qt5/ssl/certs`, then against the phone's own store (with any certificates the user installed). |
| Qt Sensors | `QT += sensors`, `import QtSensors 5.15` | Through the phone's sensord: accelerometer, orientation, rotation, compass, magnetometer, ambient light, proximity, tap. |
| Qt Multimedia | `QT += multimedia`, `import QtMultimedia 5.15` | Through the phone's GStreamer 0.10: `MediaPlayer`/`Audio`, `VideoOutput`, `SoundEffect`, `Camera`. Video is decoded on the DSP; for smooth video the app needs the `GRP::video` credential, and for the camera it's required (step 7). |
| Qt Graphical Effects | `import QtGraphicalEffects 1.15` | All effects (blurs, shadows, glow, masks, gradients, colour effects). Blurs cost GPU time on the SGX530: prefer `cached: true` for static content. |
| Qt Quick Controls 2 | `QT += quickcontrols2`, `import QtQuick.Controls 2.15` | Default, Fusion, Material, Universal and Imagine styles. For the phone's own look, use `com.nokia.meego` (above). |
| Qt WebSockets | `QT += websockets`, `import QtWebSockets 1.15` | Client and server, `wss://` through the TLS above. |
| Qt Feedback | `import QtFeedback 5.0`; C++: `PKGCONFIG += Qt5Feedback` | Haptics through the phone's feedback daemon: `ThemeEffect` (`Press`, `Release`, their `Weak` variants, drag, `Appear`, `Disappear`), as the stock apps' touch feedback. No `HapticsEffect` (custom vibration) yet. |
| Qt Positioning | `QT += positioning`, `import QtPositioning 5.15` | Through the phone's positioning daemon, with the user's settings (GPS; network positioning goes through Nokia's online service, untested): `PositionSource`, `QGeoPositionInfoSource`, `QGeoSatelliteInfoSource` (satellites in view; the daemon sent no in-use lists in testing), area monitoring. The app needs the `Location` credential (step 7). No maps (Qt Location). |
| Qt Bluetooth | `QT += bluetooth`, `import QtBluetooth 5.15` | Classic Bluetooth through the phone's BlueZ 4: the local adapter (power, name, address), device and service discovery. Sockets (RFCOMM, L2CAP) are there but not tested yet. No Bluetooth Low Energy (BlueZ 4.91 predates it). No credential needed. |
| Qt Contacts | `QT += contacts`, `import QtContacts 5.0` | The phone's address book (Tracker), read-only: the default `QContactManager` and `ContactModel` see the people the address book shows, with names, nickname, phone numbers and e-mail addresses (home and work). Saving and removing contacts aren't supported. The app needs the `TrackerReadAccess` credential (step 7). Not yet checked on a phone. |
| Qt Document Gallery | `QT += docgallery`, `import QtDocGallery 5.0` | The phone's media index (Tracker): `DocumentGalleryModel` and `QDocumentGallery` queries over images, music, videos and documents. The app needs the `TrackerReadAccess` credential (step 7). Not yet checked on a phone. |
| Image formats | (plugins) | Besides PNG and JPEG: WebP, GIF, SVG, TIFF, TGA, ICO, ICNS, WBMP. |

## 5. Build it

With qmake (the mkspec, `linux-harmattan-g++`, is the default):

```qmake
QT += quick
CONFIG += qtquickcompiler
SOURCES += main.cpp
RESOURCES += qml.qrc
target.path = /opt/myapp/bin
INSTALLS += target
```

```sh
$WORK/host/bin/qmake myapp.pro
make
```

With CMake:

```cmake
cmake_minimum_required(VERSION 3.16)
project(myapp LANGUAGES CXX)
find_package(Qt5 5.15 REQUIRED COMPONENTS Quick QuickCompiler)
qtquick_compiler_add_resources(QML_RESOURCES qml.qrc)
add_executable(myapp main.cpp ${QML_RESOURCES})
target_link_libraries(myapp PRIVATE Qt5::Quick)
install(TARGETS myapp DESTINATION /opt/myapp/bin)
```

```sh
cmake -S myapp -B build -DCMAKE_TOOLCHAIN_FILE=$WORK/cmake/harmattan-qt5.cmake
cmake --build build
```

Either way the binary is hard-float Cortex-A8 code with DT_RPATH `/opt/qt5/lib` (Qt's own
libstdc++ and libxcb win over the phone's older ones) and the phone's loader,
`/lib/ld-linux.so.3`. To compile by hand, pass `--sysroot=$WORK/sysroot` and the flags in
`cmake/harmattan-qt5.cmake`.

## 6. Run it on the phone

With the runtime installed (step 3), copy the binary and start it in the phone's session.
The session bus address is what lets it reach the keyboard:

```sh
scp myapp user@<phone>:/home/user/
ssh user@<phone> '. /tmp/session_bus_address.user; DISPLAY=:0 /home/user/myapp'
```

## 7. Package it

An app package puts the binary under `/opt/<app>/`, a `.desktop` file in
`/usr/share/applications/` and an 80×80 icon in `/usr/share/icons/hicolor/80x80/apps/`.
It depends on the runtime and carries `DEBIAN/digsigsums` (closed-mode phones check it).
Its members are gzip-compressed, because the phone's dpkg is 1.15.

The `.desktop` file runs the binary directly, not through `invoker`: its boosters preload
Qt 4.

```ini
[Desktop Entry]
Type=Application
Name=My App
Exec=/opt/myapp/bin/myapp
Icon=/usr/share/icons/hicolor/80x80/apps/myapp80.png
X-Window-Icon=
X-HildonDesk-ShowInToolbar=true
X-Osso-Type=application/x-executable
```

```sh
APP=myapp VERSION=1.0.0
S=$(mktemp -d)/$APP
install -D -m755 build/$APP "$S/opt/$APP/bin/$APP"
install -D -m644 $APP.desktop "$S/usr/share/applications/$APP.desktop"
install -D -m644 ${APP}80.png "$S/usr/share/icons/hicolor/80x80/apps/${APP}80.png"
mkdir -p "$S/DEBIAN"
cat > "$S/DEBIAN/control" <<EOF
Package: $APP
Version: $VERSION
Architecture: armel
Maintainer: Your Name <you@example.com>
Installed-Size: $(du -sk --exclude=DEBIAN "$S" | cut -f1)
Section: user/other
Priority: optional
Depends: qt5-harmattan (>= 5.15.19-6), qt5-meego-components (>= 5.15.19-6), qt5-meego-inputcontext (>= 5.15.19-6)
Description: One-line summary
 A longer description, each line indented by one space.
EOF
perl "$QT_SDK_PATH/Madde/madbin/gendigsigsums" -o com.nokia.maemo "$S.digsigsums" "$S"
mv "$S.digsigsums" "$S/DEBIAN/digsigsums"
dpkg-deb --root-owner-group -Zgzip --build "$S" ${APP}_${VERSION}_armel.deb
```

Install it on the phone as in step 3 (`devel-su`, then `dpkg -i`).

**Apps that play video** should also request Aegis' `GRP::video` credential. With it, the
DSP decodes straight into memory the GPU draws from, and `VideoOutput` shows the frames without
copying them (a stock 854×480 video: about 40% CPU for the whole app, smooth). Without it Qt
copies each frame into a texture: the video still plays, at about twice the CPU and not
smoothly. The request is an Aegis manifest naming the binary:

```xml
<aegis>
  <request>
    <credential name="GRP::video" />
    <for path="/opt/myapp/bin/myapp" />
  </request>
</aegis>
```

It goes into the package as an extra member named `_aegis`, after `dpkg-deb`:

```sh
cp myapp.aegis _aegis && ar q ${APP}_${VERSION}_armel.deb _aegis
```

The SDK's `video-app/` is a complete example: `video-app/build-deb.sh` builds its package into
`$WORK/deb`.

**Apps that use the camera** need `GRP::video` too: without it the camera devices can't be
opened. With it, Qt uses Nokia's camera stack, and the viewfinder is shown without copying
(about 20% CPU):

- `QtMultimedia.availableCameras` lists `primary` (the back camera: 8 MP, autofocus, flash) and
  `secondary` (the front camera: VGA, fixed focus). Switch with `Camera.position` or
  `Camera.deviceId`. The front camera's images come mirrored: Qt corrects the viewfinder, and
  photos carry the EXIF orientation that says so.
- Photos are taken at the viewfinder's size (816×608) unless the app sets
  `imageCapture.resolution`, for example to the largest of `imageCapture.supportedResolutions`
  (3280×2464 on the back camera).
- Stopping and starting, unloading, and switching cameras restart the camera through its
  unloaded state: allow 2–3 s before it's active again.

**Apps that use positioning** need Aegis' `Location` credential: the phone's positioning
daemon only answers processes that hold it. Request it as above, with
`<credential name="Location" />`. Without it `PositionSource.sourceError` becomes
`PositionSource.AccessError` as soon as the source is started.

**Apps that read contacts or the media gallery** need Aegis' `TrackerReadAccess` credential:
both modules query the phone's Tracker database, which answers only processes that hold it.
Request it as above, with `<credential name="TrackerReadAccess" />`. Without it a contact fetch
fails with `QContactManager::PermissionsError`.

## Notes

- **`WORK` must be set** (step 2). Without it, qmake reports paths under `/sysroot` and
  CMake stops with "WORK is not set".
- **Closed-mode phones and Aegis credentials** aren't covered yet: everything is tested on a
  phone in developer (open) mode.
