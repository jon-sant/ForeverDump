#!/usr/bin/env bash
# Restore the history of nested repos (kept as bundles so the outer repo can hold their files) into a side folder.
# usage: restore_git_bundles.sh [DEST=../wowdev-nested-git]   -> DEST/<path>/ is a full clone (branch + HEAD as on the box)
# The working trees in this repo already hold the files (incl. uncommitted changes, e.g. kth/port 8 dirty files).
set -eo pipefail
cd "$(dirname "$0")/.."
DEST="${1:-../wowdev-nested-git}"
tail -n +2 _git-bundles/INDEX.tsv | while IFS=$'\t' read -r path remote branch head commits dirty bundle; do
  mkdir -p "$DEST/$(dirname "$path")"
  git clone -q "_git-bundles/$bundle" "$DEST/$path"
  git -C "$DEST/$path" checkout -q "$head"
  [ -n "$remote" ] && git -C "$DEST/$path" remote set-url origin "$remote"
  echo "restored $path @ ${head:0:10} ($commits commits)"
done
