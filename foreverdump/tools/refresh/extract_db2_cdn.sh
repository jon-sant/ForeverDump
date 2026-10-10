#!/usr/bin/env bash
# Extract DB2 tables for a WoW product from Blizzard's CDN and convert them to CSV.
# No game client needed, and no dependency on wago.tools.
#   extract: TACTTool (wowdev/TACTSharp), built by extract_ui_cdn.sh into .cache/bin
#   convert: DBC2CSV (Marlamin/DBC2CSV, uses DBCD) + latest wowdev/WoWDBDefs definitions
#
# Usage: extract_db2_cdn.sh [product=wow_classic_beta] [outdir=./db2/<product>] [region=us]
# Env:   TABLES="SpellName GlobalStrings ..."   (default: a common set)
#        ALL=1   every table whose WoWDBDefs definition lists the current build (~1100 tables)
#        NO_CSV=1  keep only the .db2 files
# Notes: CDN DB2s do NOT include hotfixes (wago.tools applies hotfixes to its CSV; the
#        client keeps them in Cache/ADB/<locale>/DBCache.bin, which DBC2CSV can apply).
#        Run extract_ui_cdn.sh once first so TACTTool exists.
set -euo pipefail
PRODUCT="${1:-wow_classic_beta}"
OUT="${2:-./db2/$PRODUCT}"
REGION="${3:-us}"
HERE="$(cd "$(dirname "$0")" && pwd)"
CACHE_DIR="${CACHE_DIR:-$HERE/.cache}"
TACTTOOL="${TACTTOOL:-$CACHE_DIR/bin/TACTTool}"
DEFS="$CACHE_DIR/WoWDBDefs"
TABLES="${TABLES:-GlobalStrings SpellName Spell SpellMisc SpellEffect ChrClasses ChrRaces ChrSpecialization Map UiMap AreaTable Item ItemSparse Faction CurrencyTypes UiTextureAtlas UiTextureAtlasMember UiTextureAtlasElement}"
export PATH="$HOME/.dotnet:$PATH" DOTNET_ROOT="${DOTNET_ROOT:-$HOME/.dotnet}" DOTNET_NOLOGO=1 DOTNET_CLI_TELEMETRY_OPTOUT=1
export DOTNET_ROLL_FORWARD=Major   # DBC2CSV targets net8.0; let it run on the net9 runtime

[[ -x "$TACTTOOL" ]] || { echo "TACTTool not found at $TACTTOOL; run extract_ui_cdn.sh first (it builds it)." >&2; exit 1; }

# Definitions: always refresh (new builds need new definitions)
if [[ -d "$DEFS/.git" ]]; then git -C "$DEFS" pull -q --ff-only; else git clone -q --depth 1 https://github.com/wowdev/WoWDBDefs "$DEFS"; fi

# DBC2CSV build (once)
DBC2CSV="$CACHE_DIR/dbc2csv-bin/DBC2CSV"
if [[ ! -x "$DBC2CSV" && -z "${NO_CSV:-}" ]]; then
  [[ -d "$CACHE_DIR/DBC2CSV/.git" ]] || git clone -q --depth 1 https://github.com/Marlamin/DBC2CSV "$CACHE_DIR/DBC2CSV"
  dotnet build -c Release -o "$CACHE_DIR/dbc2csv-bin" --property WarningLevel=0 --verbosity quiet "$CACHE_DIR/DBC2CSV/DBC2CSV/DBC2CSV.csproj"
fi
[[ -z "${NO_CSV:-}" ]] && { rm -rf "$CACHE_DIR/dbc2csv-bin/definitions"; ln -s "$DEFS/definitions" "$CACHE_DIR/dbc2csv-bin/definitions"; }

read -r BC CC VER < <(curl -fsS "https://us.version.battle.net/v2/products/$PRODUCT/versions" \
  | awk -F'|' -v r="$REGION" '$1==r {print $2, $3, $6; exit}')
[[ -n "${VER:-}" ]] || { echo "No version row for $PRODUCT/$REGION" >&2; exit 1; }
echo "Product $PRODUCT  version $VER"

WORK="$CACHE_DIR/work-$PRODUCT"; mkdir -p "$WORK" "$OUT"; OUT="$(cd "$OUT" && pwd)"; cd "$WORK"
[[ -s listfile.csv ]] || curl -fsSL -o listfile.csv https://github.com/wowdev/wow-listfile/releases/latest/download/community-listfile.csv

if [[ -n "${ALL:-}" ]]; then
  TABLES=$(grep -l "BUILD.*$VER" "$DEFS"/definitions/*.dbd | xargs -n1 basename | sed 's/\.dbd$//')
fi
# Build "fdid;DBFilesClient/<Table>.db2" lines (FDID from the community listfile, casing from the table name)
grep -i ';dbfilesclient/[^/]*\.db2' listfile.csv | tr -d '\r' > db2-fdids.txt   # one pass over the big listfile
printf '%s\n' $TABLES | awk -F';' 'NR==FNR { split($2,a,"/"); n=tolower(a[2]); sub(/\.db2$/,"",n); id[n]=$1; next }
  { t=$0; k=tolower(t); if (k in id) print id[k] ";DBFilesClient/" t ".db2"; else print "  (no FileDataID for " t " in listfile)" > "/dev/stderr" }' db2-fdids.txt - > db2list.txt
echo "Extracting $(wc -l < db2list.txt) DB2 files..."
"$TACTTOOL" --product "$PRODUCT" --region "$REGION" --buildconfig "$BC" --cdnconfig "$CC" \
  --mode list --inputvalue db2list.txt --output "$OUT" | grep -vE '^(Downloading|Extracting)' || true

if [[ -z "${NO_CSV:-}" ]]; then
  echo "Converting to CSV with DBC2CSV..."
  "$DBC2CSV" "$OUT/DBFilesClient" 2>&1 | grep -vE '^(Exporting table|Reloading definitions)' || true
fi
echo "$VER" > "$OUT/version.txt"
echo "Done: $(ls "$OUT"/DBFilesClient/*.db2 2>/dev/null | wc -l) db2, $(ls "$OUT"/DBFilesClient/*.csv 2>/dev/null | wc -l) csv, $(du -sh "$OUT" | cut -f1) in $OUT"
