# Qt 5 on stock Harmattan: specs and rationale

What it's building and why each big choice went the way it did. The how is in
`PLAN.md`. Revisit a choice only with new evidence, and record the change here.

## What

A usable Qt 5.15 SDK for writing Qt Quick 2 apps for the Nokia N9 / N950 on **stock**
Harmattan PR1.3:
- It installs next to the system Qt 4.7.4, under `/opt/qt5`, as `.deb`s.
- It works on open-mode and closed-mode phones.
- Apps look and behave like native Harmattan apps: GPU rendering, the stock keyboard,
  rotation, multitouch, and `com.nokia.meego`.
- Developers build with a cross toolchain on Linux (qmake or CMake).

## Choices

### Qt 5, not Qt 6

- **Nothing to gain on this hardware.** The GPU is an SGX530 with OpenGL ES 2.0. Qt 6's
  rendering layer (RHI) and build-time shader step (qtshadertools) add build and
  runtime weight and bring nothing an ES 2.0 GPU can use.
- **The N9-specific pieces already exist for Qt 5:**
  - `com.nokia.meego` ported to Qt Quick 2 (nemomobile qt-components, `qtquick2`),
  - a Qt 5 Maliit input context (0.99.1) that speaks the phone's keyboard protocol,
  - the N9 multitouch code that Qt 5.0–5.3 carried.

  For Qt 6, all three would have to be ported again.
- **Porting existing N9 apps is shorter.** Qt 4 QML apps map onto Qt Quick 2 and a Qt 5
  `com.nokia.meego` mostly through import changes.

### Qt 5.15, from KDE's patch collection

- 5.15 is the last and most complete Qt 5. Since we have a GCC 14 cross toolchain, the
  compiler doesn't force an older release.
- KDE's `kde/5.15` branch is kept building with current GCC and supports OpenSSL 3.

### Next to Qt 4, not replacing it

- Every system app is built on Qt 4.7, and closed mode forbids replacing Nokia's
  packages. So Qt 5 lives in `/opt/qt5` and touches nothing of the system's.
- Qt 4 apps are untouched.

### X11 (xcb), not eglfs or Wayland

- The phone's UI is an X11 compositor (mcompositor). Qt 5 apps must be ordinary windows
  in it, so they get swiping, the switcher, notifications and the keyboard. eglfs would
  take over the whole screen, and there's no Wayland on the phone.
- The stock xcb plugin with EGL covers this, with one patch (multitouch). We don't
  maintain a fork of the whole plugin, as qtinsider's attempt did.

### The shared GCC 14 toolchain

- GCC 14.2 and binutils 2.42 from harmattan-toolchain, a separate repo that any Harmattan
  app can use (`scripts/build-toolchain.sh` runs its build). It builds against a sysroot copy
  in which glibc's long-double math declarations are visible: against the stock sysroot,
  libstdc++ leaves out C++11 `<cmath>` and C99 `<complex>`, which Qt needs and so do apps
  (2026-09-26, task 2.2).

### Our own libstdc++, libgcc_s and libxcb in `/opt/qt5/lib`

- Qt 5.15 needs a C++ runtime newer than the phone's (GCC 4.4) and libxcb ≥ 1.11 (the
  phone has 1.7).
- Qt is many shared libraries, so linking the C++ runtime statically into each would put
  several copies in one process, which breaks exceptions and RTTI. One shared copy it
  is.
- Our libxcb carries one Nokia addition, `xcb_poll_for_next_event`, because the
  system libX11 calls it (`patches/libxcb/`).
- These libraries share their SONAMEs with the phone's older copies. RPATH alone
  doesn't place ours: the SGX libraries' own DT_RPATH sends their dependencies to
  `/usr/lib`. So ours load first, as direct dependencies of the Qt libraries, and the
  system libraries reuse them. `ld.so` uses the
  first one loaded for the whole process, so ours win in Qt 5 apps. All three kept
  backward-compatible ABIs, so the system libraries loaded alongside keep working.
- **The cost:** Qt 5 apps can't use applauncherd's boosters (they preload Qt 4 and the
  old runtime), so cold starts are slower. Accepted; measured in task 3.5.

### Multitouch by porting Qt 5.0–5.3's N9 code, not by replacing the X server

- The phone's X server speaks XInput 2.0. Qt 5.15's touch support needs 2.2.
- **Replacing the X server** would mean rebuilding or porting Nokia's X video driver
  (it contains the GPU's DRI2 glue), the `mtev` touch driver, Nokia's `policy` extension
  and Nokia's server patches. It's also impossible on closed-mode phones, because
  Nokia's packages can't be replaced from another source. That's a separate project.
- **Porting instead:** the phone's touch driver already reports every finger, and Qt 4.7
  and Qt 5.0–5.3 decoded that. Porting that one file restores multitouch without
  touching the system.

### Keyboard: qtinsider's Qt 5 Maliit input context, patched

- The phone runs Maliit 0.81, and Nokia's 0.81.7 speaks exactly 0.81.4's protocol
  (checked against the phone binaries, task 3.1a).
- Patching an existing, protocol-compatible plugin is far less work than writing one.
- Changed 2026-09-26, from Maliit 0.99.1's `input-context/`: `qtinsider/maliit` is the
  same Qt 5 input-context code, already standalone (one qmake plugin, about 1,400 lines,
  with no 0.99.1 `connection/`/`common/` to carry). It already avoids 0.99.1's extra
  calls, so it lacks only `copy` and `paste`. 0.99.1 stays the fallback.

### Look and feel: nemomobile's Qt 5 `com.nokia.meego`

- It keeps the Harmattan component API that N9 apps and developers know, and draws with
  the phone's own theme (blanco), so apps look native.

### Orientation: ContextKit `Screen.TopEdge` over D-Bus

- It's what the Qt 4 components use, so the behaviour matches system apps.
- It needs no ContextKit library and no Aegis credentials; any process may read it.

### TLS: OpenSSL 3.5

- Qt supports it without patches, and it builds for the phone as it is.
- Apache-2.0: it puts no licence constraint on apps. wolfSSL would have needed a Qt
  patch and, being GPL, would have forced every networked app to be GPL-compatible.

### Fonts: system FreeType and fontconfig

- The phone's fonts, including Nokia Pure, are configured through fontconfig, and Qt
  enables fontconfig only with the system FreeType.

### Closed mode is a requirement

- Stock N9s ship in closed mode. An SDK whose apps only run on open-mode phones is only
  useful to tinkerers. Everything is packaged with Aegis reference hashes from the
  start, even though testing happens on an open-mode phone.

## Not doing

| What | Why |
|---|---|
| Qt 6 | see above |
| QtWebEngine | Chromium is far too heavy for a single-core 1 GHz Cortex-A8 with 1 GB RAM, and needs a much newer platform |
| Replacing system Qt 4 | system apps depend on Qt 4; closed mode forbids replacing it |
| Replacing the X server | see "Multitouch" above; its own plan if ever |
| Mainline kernel / Maemo Leste | a different target: this is about stock Harmattan |
