#!/usr/bin/env bash
# Task 0.3: fetch the upstream sources into $WORK/src (the sysroot comes with the toolchain:
# scripts/build-toolchain.sh). Re-running skips whatever is already there.
set -euo pipefail
. "$(dirname "$0")/env.sh"
mkdir -p "$WORK/src" && cd "$WORK/src"

# Pinned to the commits our patches apply to (the branch or tag each came from in the comment):
# a release's binaries are built from exactly these. Shallow: we only diff against them;
# `git fetch --unshallow` if history is ever needed.
clone() { # dir url commit
    [ -d "$1" ] && return
    git init -q "$1"
    git -C "$1" remote add origin "$2"
    git -C "$1" fetch -q --depth 1 origin "$3"
    git -C "$1" checkout -q FETCH_HEAD
}
kde() { clone "$1" "https://invent.kde.org/qt/qt/$1.git" "$2"; }   # KDE's Qt 5 patch collection, kde/5.15

kde qtbase             fbed962c3195ab3952fa54d40e012ad1a4fdc42b
kde qtdeclarative      5bc1ac07b2d2c7839368084a4bb97e4c67eb8294
kde qtsvg              d2abfb9cb1f036446e5913fadb0f065dab9f0159
kde qtmultimedia       8ddc44103baf166525d6650c842d7f08f651e7bb
kde qtsensors          8c6d11df60d4d783869c2d81568e3178f5ae75ce
kde qtgraphicaleffects 551732fb1d963e53af437e3982a010f69eb76253
kde qtimageformats     4076e38d68f05f5e1bcdedb79442d9008f18702c
kde qtwebsockets       10eb706b24aa05f4ee69c2f2fec99b21994dfe2b
kde qtquickcontrols2   5b808e0995d018c6de9f075d4a61f58d3641c11b
kde qtlocation         81f560be2274958011c255efa1d2d573874bed11
kde qtconnectivity     7e29434e06372efbb2127d0ef41538ff9aec1597
clone qt-components https://github.com/nemomobile/qt-components c967fbd79e75c9866061d995c08eae82678b538c # qtquick2
clone qtinsider-maliit https://github.com/qtinsider/maliit 879a7f2e3bc7da249e5f7fca0d19c72c8991d70e # master
clone libxkbcommon-1.13.2 https://github.com/xkbcommon/libxkbcommon d1442aaa6b635551182e83c3b55037f4c118c962 # xkbcommon-1.13.2
# Phase 4: the Qt 5 sensord client for qtsensors (patches/sensorfw: the phone's 0.6.46 protocol).
clone sensorfw https://github.com/sailfishos/sensorfw b37c5b467e8be554066dfd1c4138dbff8eec77b3 # 0.15.2
# Task 6: QtFeedback (ThemeEffect) for Qt 5; patches/qtfeedback adds a meegofeedbackd backend.
clone qtfeedback https://github.com/sailfishos/qtfeedback 2cd40d1deca20f883107215cb826fd47c408a5cb # mer-master
# References only, not built: an earlier xcb plugin for the N9, and Maliit's protocol versions.
clone qt5-meego-platform-plugin https://github.com/qtinsider/qt5-meego-platform-plugin 7085af3d5b8e29715149b9636c49af345510178a # master
clone maliit-0.81.4 https://github.com/maliit/framework 3431d906d11f8cc81754432bda52abcea8e0f083 # 0.81.4
clone maliit-0.99.1 https://github.com/maliit/framework b8072bdcbf858214b4d0569298057beeb82e9fa7 # 0.99.1

for t in xcb-proto-1.17.0 libxcb-1.17.0 xcb-util-0.4.1 xcb-util-image-0.4.1 \
         xcb-util-keysyms-0.4.1 xcb-util-wm-0.4.2 xcb-util-renderutil-0.3.10; do
    [ -d "$t" ] || curl -fsSL "https://xorg.freedesktop.org/releases/individual/xcb/$t.tar.xz" | tar xJ
done

for d in */.git; do
    printf '%s %s\n' "${d%/.git}" "$(git -C "${d%/.git}" rev-parse HEAD)"
done
