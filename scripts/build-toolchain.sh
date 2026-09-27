#!/usr/bin/env bash
# The GCC 14 cross toolchain into $WORK/cross, against $WORK/sysroot: harmattan-toolchain's
# build.sh (its own repo; HARMATTAN_TOOLCHAIN, default next to this checkout). It also makes
# $WORK/sysroot from Nokia's (MADDE_SYSROOT, env.sh), with the long double math declarations
# libstdc++ needs. Stages already installed are skipped.
set -euo pipefail
. "$(dirname "$0")/env.sh"
TC=${HARMATTAN_TOOLCHAIN:-$WORK/../harmattan-toolchain}
[ -x "$TC/build.sh" ] || { echo "No harmattan-toolchain at $TC: clone it there or set HARMATTAN_TOOLCHAIN." >&2; exit 1; }
"$TC/build.sh" "$WORK"
