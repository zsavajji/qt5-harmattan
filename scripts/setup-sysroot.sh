#!/usr/bin/env bash
# In an SDK bundle (scripts/package-sdk.sh): builds $WORK/sysroot from MADDE's Harmattan sysroot
# (without usr/local, as fetch-sources.sh copies it) and the bundle's changes to it:
# sysroot-overlay/ (/opt/qt5, the header fixes, the extra headers and .so links) and
# sysroot-removed.txt (MADDE's libxcb 1.7 dev files). Re-runnable. MADDE comes from the Qt SDK
# 1.2.1 (Harmattan target); set QT_SDK_PATH or MADDE_SYSROOT if it isn't in ~/QtSDK.
set -euo pipefail
. "$(dirname "$0")/env.sh"
[ -f "$MADDE_SYSROOT/usr/include/features.h" ] || {
    echo "No MADDE sysroot at $MADDE_SYSROOT: install the Qt SDK's Harmattan target, or set QT_SDK_PATH or MADDE_SYSROOT." >&2
    exit 1
}
[ -d "$WORK/sysroot-overlay" ] || { echo "$WORK has no sysroot-overlay/: run this in an SDK bundle." >&2; exit 1; }
rsync -a --delete --exclude /usr/local/ "$MADDE_SYSROOT/" "$WORK/sysroot/"
while IFS= read -r f; do rm -rf "${WORK:?}/sysroot/$f"; done < "$WORK/sysroot-removed.txt"
rsync -a "$WORK/sysroot-overlay/" "$WORK/sysroot/"
echo "== sysroot ready: $WORK/sysroot"
