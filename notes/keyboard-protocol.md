# Keyboard protocol check (task 3.1a, 2026-09-26)

## 1. Nokia's 0.81.7 vs public Maliit 0.81.4: identical

Method names and argument signatures were read from the dbus-glib introspection data
embedded in the PR1.3 binaries (rootfs), and compared with 0.81.4's
`connection/minputmethod{server,context}1interface.xml`:

| Interface | Phone binary | Methods | Result |
|---|---|---|---|
| `com.meego.inputmethod.uiserver1` (the app calls the server) | `usr/bin/meego-im-uiserver` | 15 | same names, same signatures |
| `com.meego.inputmethod.inputcontext1` (the server calls the app) | `usr/lib/qt4/plugins/inputmethods/libminputcontext.so` | 16 | same names, same signatures |

Nokia changed nothing in the protocol, so the 0.81.4 XML is the reference.

## 2. `qtinsider/maliit` is N9-specific, and a better base than 0.99.1

- It's a single commit (2019-10-11, `879a7f2`) with no shared history with
  maliit/framework. The code is Qt 5's old in-tree Maliit platform input context
  (Nokia/Digia/Jolla copyright), made standalone for the N9. qtbase 5.15 no longer
  carries that plugin (`platforminputcontexts/` has only compose and ibus).
- 1,443 lines, one qmake plugin (`load(qt_plugin)`, `QT += dbus gui-private`), plugin key
  `minputcontext`. It builds against our Qt with nothing from 0.99.1.
- It finds the server through `org.maliit.server` → `org.maliit.Server.Address`, the
  phone's mechanism.
- Against the phone's protocol:
  - **inputcontext1:** implements 14 of 16. **Missing `copy` and `paste`** (no arguments).
    Without them the adaptor rejects the server's calls with an error reply.
  - **uiserver1:** calls 14 of 15. Missing only
    `appOrientationAboutToChangeWithPixmapHandle`, which is optional.
  - Never calls `loadPluginSettings` and has no `invokeAction`, so the 0.99.1-only
    differences don't arise.
  - Orientation: sends `appOrientationChanged` on the window's
    `contentOrientationChanged`, which 3.2 drives.
- Checked statically against the phone: the same bus names (`org.maliit.server`), object
  paths (`/com/meego/inputmethod/inputcontext`, `/com/meego/inputmethod/uiserver1`),
  method names and argument types as the phone's binaries, apart from `copy`/`paste`.
  **Not yet run on a phone:** nothing shows it ever worked on an N9.
- **Bug:** the fallback address when `org.maliit.server` is missing is the literal
  `unix:path=/tmp/meego-im-uiserver/d->server_dbus` (`qmaliitplatforminputcontext.cpp:76`).
  It's harmless on the phone, where the name exists; fix it or drop it.

## Consequence for 3.1b

Start from `qtinsider/maliit` (in `<WORK>/src/qtinsider-maliit`): add `copy`/`paste`
to the adaptor (slots plus its introspection string) and forward them as
`QKeySequence::Copy`/`Paste` key events to the focus object, then fix the fallback
address. Maliit 0.99.1's `input-context/` stays the fallback.

The user's clone `~/projects/keyboard` on the box is `maliit/keyboard` (2.3.1+), a
keyboard UI for a Maliit 2.x server. The plan keeps the phone's stock keyboard, so it
isn't needed.

## Result (3.1b, 2026-09-26)

Confirmed on the N9: unpatched, `qtinsider/maliit` opened the keyboard and delivered text.
The patch (`patches/qtinsider-maliit/0001-…`) adds `copy`/`paste` and copy/paste state,
closes the keyboard when focus leaves text input (Qt Quick never asks to hide), and
aligns the default orientation with the window angle. Details: PLAN.md, 3.1b.
