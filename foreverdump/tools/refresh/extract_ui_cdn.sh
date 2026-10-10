#!/usr/bin/env bash
# Extract Blizzard's UI source (Lua/XML/TOC) for a WoW product straight from
# Blizzard's public CDN. No game client, account, or login needed.
#
# This is a bash port of Gethe/wow-ui-source's own CI exporter
# (branch "automation", ExportInterfaceFiles.ps1). It uses the same tool,
# TACTTool from wowdev/TACTSharp, pinned to the same commit, and the same
# three manifest FileDataIDs.
#
# Usage: extract_ui_cdn.sh [product] [outdir] [region]
#   product: default wow_classic_beta (WoW Forever beta)
#   outdir:  default ./ui-source/<product>
# Env:
#   TACTTOOL=/path/to/TACTTool   use this binary instead of building one
#   CACHE_DIR=...                where TACTSharp, the build and the CDN cache live
# Needs: git, curl, ping (TACTSharp pings the CDNs to rank them), and a
# .NET 9 SDK, which is only used the first time to build TACTTool.
set -euo pipefail

PRODUCT="${1:-wow_classic_beta}"
OUT="${2:-./ui-source/$PRODUCT}"
REGION="${3:-us}"
HERE="$(cd "$(dirname "$0")" && pwd)"
CACHE_DIR="${CACHE_DIR:-$HERE/.cache}"
TACTSHARP_COMMIT="de24db8794708fd40f98d8894a1a0a05593e3628"   # Gethe automation submodule pin (net9.0)

mkdir -p "$CACHE_DIR"

# 1) Get TACTTool
if [[ -z "${TACTTOOL:-}" ]]; then
  TACTTOOL="$CACHE_DIR/bin/TACTTool"
  if [[ ! -x "$TACTTOOL" ]]; then
    command -v dotnet >/dev/null || export PATH="$HOME/.dotnet:$PATH" DOTNET_ROOT="$HOME/.dotnet"
    command -v dotnet >/dev/null || { echo "dotnet SDK 9 not found. Install: curl -sSL https://dot.net/v1/dotnet-install.sh | bash -s -- --channel 9.0" >&2; exit 1; }
    [[ -d "$CACHE_DIR/TACTSharp/.git" ]] || git clone -q https://github.com/wowdev/TACTSharp "$CACHE_DIR/TACTSharp"
    git -C "$CACHE_DIR/TACTSharp" fetch -q origin && git -C "$CACHE_DIR/TACTSharp" checkout -q "$TACTSHARP_COMMIT"
    DOTNET_NOLOGO=1 DOTNET_CLI_TELEMETRY_OPTOUT=1 dotnet build --configuration Release \
      --output "$CACHE_DIR/bin" --property WarningLevel=0 --verbosity quiet \
      "$CACHE_DIR/TACTSharp/TACTTool/TACTTool.csproj"
  fi
fi
command -v ping >/dev/null || echo "WARNING: 'ping' not found; TACTSharp needs it to rank CDNs (apt install iputils-ping)." >&2
[[ "$TACTTOOL" == */* ]] || TACTTOOL="$(command -v "$TACTTOOL")"
case "$TACTTOOL" in /*) ;; *) TACTTOOL="$PWD/$TACTTOOL" ;; esac

# 2) Current build on Blizzard's patch service (same endpoint Gethe uses)
read -r BC CC VER < <(curl -fsS "https://us.version.battle.net/v2/products/$PRODUCT/versions" \
  | awk -F'|' -v r="$REGION" '$1==r {print $2, $3, $6; exit}')
[[ -n "${VER:-}" ]] || { echo "No version row for $PRODUCT/$REGION" >&2; exit 1; }
echo "Product $PRODUCT  region $REGION  version $VER"
echo "BuildConfig $BC  CDNConfig $CC"

mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"
find "$OUT" -maxdepth 1 -name 'Interface*' -exec rm -rf {} +   # prune stale files, like Gethe does
WORK="$CACHE_DIR/work-$PRODUCT"; mkdir -p "$WORK"; cd "$WORK"   # TACTSharp keeps its CDN cache in ./cache

# 3) The three UI manifests (FileDataIDs from Gethe's exporter)
printf '%s\n' "6067012;Interface/ui-code-list.txt" "6067013;Interface/ui-toc-list.txt" "6076661;Interface/ui-gen-addon-list.txt" > manifests.txt
"$TACTTOOL" --product "$PRODUCT" --region "$REGION" --buildconfig "$BC" --cdnconfig "$CC" \
  --mode list --inputvalue manifests.txt --output "$OUT" | grep -v '^Downloading' || true

# 4) Every file the manifests list (by name; the names are in the TACT root)
cat "$OUT/Interface/ui-code-list.txt" "$OUT/Interface/ui-toc-list.txt" "$OUT/Interface/ui-gen-addon-list.txt" \
  | tr -d '\r' | sed 's#\\#/#g' | sort -u | sed '/^$/d' > files.txt
echo "Extracting $(wc -l < files.txt) UI files..."
"$TACTTOOL" --product "$PRODUCT" --region "$REGION" --buildconfig "$BC" --cdnconfig "$CC" \
  --mode list --inputvalue files.txt --output "$OUT" | grep -vE '^(Downloading|Extracting)' || true

echo "$VER" > "$OUT/version.txt"
echo "Done: $(find "$OUT/Interface" -type f | wc -l) files, $(du -sh "$OUT" | cut -f1) in $OUT (build $VER)"
