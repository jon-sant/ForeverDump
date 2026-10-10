#!/usr/bin/env bash
# Fetch/refresh the community-maintained WoW Forever data (no game client needed).
#   1. Gethe/wow-ui-source       branch "forever"  (Blizzard UI Lua/XML/TOC, CI-extracted from the CDN)
#   2. Ketho/BlizzardInterfaceResources branch "forever" (KethoDoc in-game dump + wago GlobalStrings/AtlasInfo)
#   3. wago.tools DB2 -> CSV for the product (default wow_classic_beta)
#
# Usage: fetch_community.sh [destdir=./community] [product=wow_classic_beta]
# Env:   BRANCH=forever   TABLES="SpellName GlobalStrings ..."   SKIP_GIT=1   SKIP_WAGO=1
#        WAGO_BUILD=1.60.1.70245  (pin a build instead of ?branch=<product>)
set -euo pipefail
DEST="${1:-$(pwd)/community}"
PRODUCT="${2:-wow_classic_beta}"
BRANCH="${BRANCH:-forever}"
TABLES="${TABLES:-GlobalStrings SpellName Spell SpellMisc ChrClasses ChrRaces ChrSpecialization Map UiMap AreaTable Item ItemSparse Faction CurrencyTypes UiTextureAtlas UiTextureAtlasMember UiTextureAtlasElement Achievement QuestV2 Mount}"
mkdir -p "$DEST"

sync_repo() { # url dir
  local url="$1" dir="$2"
  if [ -d "$dir/.git" ]; then
    git -C "$dir" fetch -q --depth 1 origin "$BRANCH"
    git -C "$dir" checkout -q -B "$BRANCH" FETCH_HEAD
  else
    git clone -q --depth 1 --single-branch -b "$BRANCH" "$url" "$dir"
  fi
  printf '  %-28s %s  %s  (%s)\n' "$(basename "$dir")" "$(git -C "$dir" log -1 --format='%h %cs %s')" "" "$(du -sh --exclude=.git "$dir" | cut -f1)"
}

if [ -z "${SKIP_GIT:-}" ]; then
  echo "== git ($BRANCH, --depth 1)"
  sync_repo https://github.com/Gethe/wow-ui-source.git "$DEST/wow-ui-source"
  sync_repo https://github.com/Ketho/BlizzardInterfaceResources.git "$DEST/BlizzardInterfaceResources"
fi

if [ -z "${SKIP_WAGO:-}" ]; then
  Q="branch=$PRODUCT"; [ -n "${WAGO_BUILD:-}" ] && Q="build=$WAGO_BUILD"
  OUT="$DEST/db2csv-wago/$PRODUCT"; mkdir -p "$OUT"
  VER=$(curl -fsS "https://wago.tools/api/builds/$PRODUCT/latest" | python3 -c 'import json,sys;print(json.load(sys.stdin)["version"])' || echo unknown)
  echo "== wago.tools DB2 CSV ($Q, latest $PRODUCT = $VER)"
  for t in $TABLES; do
    code=$(curl -sS -L -o "$OUT/$t.csv.part" -w '%{http_code}' "https://wago.tools/db2/$t/csv?$Q" || echo 000)
    if [ "$code" = 200 ]; then mv "$OUT/$t.csv.part" "$OUT/$t.csv"; printf '  %-24s %8s lines  %s\n' "$t" "$(($(wc -l <"$OUT/$t.csv")-1))" "$(du -h "$OUT/$t.csv" | cut -f1)"
    else rm -f "$OUT/$t.csv.part"; echo "  $t: HTTP $code (table missing in this build?)"; fi
    sleep 0.3   # be polite to wago.tools
  done
  echo "$VER" > "$OUT/version.txt"
fi
echo "== total: $(du -sh --exclude=.git "$DEST" | cut -f1) in $DEST"
