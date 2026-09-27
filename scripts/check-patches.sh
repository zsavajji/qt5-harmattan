#!/usr/bin/env bash
# Check that each patch series applies, in order, to a pristine copy of its pinned source
# and reproduces the working tree in $WORK/src exactly. Run on the box after changing a
# patch: patches made with "git diff" on a tree that already has earlier patches applied
# silently include their hunks (2.3/3.2: 0006 and 0007 did). The modules run in parallel.
set -euo pipefail
. "$(dirname "$0")/env.sh"
cd "$WORK"
R=$WORK/build/patchcheck
rm -rf "$R" && mkdir -p "$R"

check() { # module: prints its report, exits 1 on a failure
    local name=$1 src=src/$1 W=$R/$1 fail=0
    git -C "$src" rev-parse --git-dir >/dev/null 2>&1 || { echo "$name: not a git checkout, skipped"; return 0; }
    echo "$name:"
    mkdir -p "$W"
    git -C "$src" archive HEAD | tar -C "$W" -x
    for p in "patches/$name"/*.patch; do
        if patch -d "$W" -p1 -s --dry-run < "$p" >/dev/null 2>&1; then
            patch -d "$W" -p1 -s < "$p"; echo "  ok    ${p##*/}"
        else
            echo "  FAIL  ${p##*/}"; fail=1
        fi
    done
    while read -r f; do
        [ "$f" = ./.tag ] && continue   # filled in by git archive
        cmp -s "$W/$f" "$src/$f" || { echo "  DIFFERS from the working tree: $f"; fail=1; }
    done < <(cd "$W" && find . -type f)
    rm -rf "$W"
    return $fail
}

for dir in patches/*/; do
    name=$(basename "$dir")
    check "$name" > "$R/$name.log" 2>&1 &
done
fail=0
for dir in patches/*/; do
    wait -n || fail=1
done
cat "$R"/*.log
rm -rf "$R"
[ $fail = 0 ] && echo "== patches ok" || { echo "== patches FAILED"; exit 1; }
