#!/usr/bin/env bash
# One-shot refresh: detect a new Forever build and regenerate everything that does
# not need the game client. Safe to run from cron / a scheduled task.
#
# Usage: refresh_all.sh [--force] [product=wow_classic_beta]
# Env:   DATA=/workspace/foreverdump/data   (output root)
# Output layout:
#   $DATA/ui-source/<product>/     Blizzard UI Lua/XML/TOC from the CDN (git repo: one commit per build -> easy diffs)
#   $DATA/db2/<product>/DBFilesClient/*.db2 + *.csv   DB2 tables from the CDN, converted with DBC2CSV
#   $DATA/community/               Gethe + Ketho BIR forever branches, wago.tools CSVs
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
FORCE=""; [[ "${1:-}" == "--force" ]] && { FORCE=1; shift; }
PRODUCT="${1:-wow_classic_beta}"
DATA="${DATA:-$(cd "$HERE/../.." && pwd)/data}"
STATE="$HERE/.state/last_build-$PRODUCT.json"

set +e; python3 "$HERE/check_build.py" --product "$PRODUCT" --state "$STATE"; rc=$?; set -e
[[ $rc == 2 ]] && { echo "patch service unreachable" >&2; exit 2; }
if [[ $rc != 10 && -z "$FORCE" && -f "$STATE" ]]; then echo "Nothing to do."; exit 0; fi

UI="$DATA/ui-source/$PRODUCT"
"$HERE/extract_ui_cdn.sh" "$PRODUCT" "$UI"
VER="$(cat "$UI/version.txt")"
# Keep a local history of the UI source so you can diff builds (git diff HEAD~1 --stat)
( cd "$UI" && { [[ -d .git ]] || { git init -q && printf '* text=auto eol=lf\n' > .gitattributes; }; }
  git -c core.safecrlf=false add -A && git -c user.name=refresh -c user.email=refresh@localhost commit -qm "$VER" && echo "ui-source: committed $VER" || echo "ui-source: no changes" )

"$HERE/extract_db2_cdn.sh" "$PRODUCT" "$DATA/db2/$PRODUCT"
"$HERE/fetch_community.sh" "$DATA/community" "$PRODUCT" || echo "WARNING: community fetch failed (CDN data above is still complete)" >&2

python3 "$HERE/check_build.py" --product "$PRODUCT" --state "$STATE" --update-state >/dev/null
echo "Refreshed $PRODUCT $VER into $DATA"
