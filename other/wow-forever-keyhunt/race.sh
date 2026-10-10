#!/usr/bin/env bash
# EVOLUTION 1: WoW Forever beta key signal race
set -u
OUTDIR="/workspace/wow-forever-keyhunt"
RESULTS_JSON="$OUTDIR/evolution-1-race.json"
CODES_FILE="$OUTDIR/codes-found.txt"
RAW="$OUTDIR/raw"
mkdir -p "$RAW"
: > "$CODES_FILE"
UA='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36'
# Patterns: classic 4-4-4-4 and longer Blizzard 4-4-5-4-4 / 5-5-5-5-5 etc.
KEY_PAT='[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}(-[A-Z0-9]{4})?'
KEY_PAT_LONG='[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{5}-[A-Z0-9]{4}-[A-Z0-9]{4}'

extract_codes() {
  local file="$1" source_url="$2"
  local tmp
  tmp=$(mktemp)
  # Pull both patterns
  grep -oE "$KEY_PAT_LONG" "$file" 2>/dev/null | sort -u >> "$tmp" || true
  grep -oE "$KEY_PAT" "$file" 2>/dev/null | sort -u >> "$tmp" || true
  # Filter noise: reject all-same, obvious placeholders, Reddit ids that look wrong
  if [[ -s "$tmp" ]]; then
    while read -r code; do
      # Skip if looks like UUID fragments with lowercase only already handled by pattern
      # Skip pure numeric-looking short noise and known fake placeholders
      case "$code" in
        XXXX-*|xxxx-*|0000-*|AAAA-*|TEST-*|DEAD-*|BEEF-*) continue ;;
      esac
      # Require at least one letter AND one digit for "real-looking"
      if echo "$code" | grep -qE '[A-Z]' && echo "$code" | grep -qE '[0-9]'; then
        echo "$code | $source_url" >> "$CODES_FILE"
        echo "$code"
      fi
    done < <(sort -u "$tmp")
  fi
  rm -f "$tmp"
}

time_ms() {
  # returns elapsed ms between start_ns and now; start_ns is $1
  local start_ns="$1"
  local end_ns
  end_ns=$(date +%s%N)
  echo $(( (end_ns - start_ns) / 1000000 ))
}

# Accumulate JSON method entries in a file
METHODS_JSON="$RAW/methods.jsonl"
: > "$METHODS_JSON"

log_method() {
  local id="$1" name="$2" ms="$3" useful="$4" http="$5" notes="$6" sample="$7" urls="$8"
  # Escape for JSON roughly
  python3 -c "
import json,sys
obj={
  'id': '''$id''',
  'name': '''$name''',
  'latency_ms': int('$ms'),
  'useful_hits': ('$useful' == 'true'),
  'http_status': '''$http''',
  'notes': '''$notes''',
  'sample_codes': '''$sample'''.split('|') if '''$sample''' else [],
  'source_urls': '''$urls'''.split('|') if '''$urls''' else [],
}
print(json.dumps(obj))
" >> "$METHODS_JSON"
}

echo "=== EVOLUTION 1 RACE START $(date -Iseconds) ==="

# ---------- A: Reddit JSON API ----------
echo "--- A: Reddit JSON ---"
START=$(date +%s%N)
A_CODES=""
A_USEFUL=false
A_STATUS=""
A_NOTES=""
A_URLS=""
for url in \
  "https://www.reddit.com/r/classicwow/new.json?limit=25" \
  "https://www.reddit.com/r/wow/new.json?limit=25" \
  "https://www.reddit.com/search.json?q=WoW+Forever+beta+(key+OR+code)&sort=new&limit=25"
do
  fname="$RAW/reddit_$(echo "$url" | md5sum | cut -c1-8).json"
  http=$(curl -sS -L -A "$UA" -H 'Accept: application/json' \
    -w '%{http_code}' -o "$fname" --max-time 20 "$url" 2>/dev/null || echo "000")
  A_STATUS="${A_STATUS}${http},"
  found=$(extract_codes "$fname" "$url" | tr '\n' '|' | sed 's/|$//')
  if [[ -n "$found" ]]; then
    A_USEFUL=true
    A_CODES="${A_CODES}${found}|"
  fi
  # Also check titles/selftext for Forever/beta keywords as signal
  if grep -qiE 'forever.*(beta|key|code)|(beta|key|code).*forever' "$fname" 2>/dev/null; then
    A_NOTES="${A_NOTES}keyword_hit;"
    A_USEFUL=true
  fi
  A_URLS="${A_URLS}${url}|"
done
A_MS=$(time_ms "$START")
A_CODES=$(echo "$A_CODES" | sed 's/|$//')
A_URLS=$(echo "$A_URLS" | sed 's/|$//')
A_NOTES="statuses=${A_STATUS}${A_NOTES}"
log_method "A" "Reddit JSON API" "$A_MS" "$A_USEFUL" "$A_STATUS" "$A_NOTES" "$A_CODES" "$A_URLS"
echo "A done: ${A_MS}ms useful=$A_USEFUL"

# ---------- B: old.reddit HTML scrape ----------
echo "--- B: old.reddit HTML ---"
START=$(date +%s%N)
B_CODES=""
B_USEFUL=false
B_STATUS=""
B_NOTES=""
B_URLS=""
for url in \
  "https://old.reddit.com/r/classicwow/new/" \
  "https://old.reddit.com/r/wow/new/" \
  "https://old.reddit.com/search/?q=WoW+Forever+beta+key&sort=new&t=week" \
  "https://old.reddit.com/search/?q=%22Forever%22+beta+(key+OR+code)+wow&sort=new&t=month"
do
  fname="$RAW/oldreddit_$(echo "$url" | md5sum | cut -c1-8).html"
  http=$(curl -sS -L -A "$UA" -w '%{http_code}' -o "$fname" --max-time 20 "$url" 2>/dev/null || echo "000")
  B_STATUS="${B_STATUS}${http},"
  found=$(extract_codes "$fname" "$url" | tr '\n' '|' | sed 's/|$//')
  if [[ -n "$found" ]]; then
    B_USEFUL=true
    B_CODES="${B_CODES}${found}|"
  fi
  if grep -qiE 'forever.*(beta|key|code)|(beta|key|code).*forever' "$fname" 2>/dev/null; then
    B_NOTES="${B_NOTES}keyword_hit;"
    B_USEFUL=true
  fi
  B_URLS="${B_URLS}${url}|"
done
B_MS=$(time_ms "$START")
B_CODES=$(echo "$B_CODES" | sed 's/|$//')
B_URLS=$(echo "$B_URLS" | sed 's/|$//')
B_NOTES="statuses=${B_STATUS}${B_NOTES}"
log_method "B" "old.reddit HTML scrape" "$B_MS" "$B_USEFUL" "$B_STATUS" "$B_NOTES" "$B_CODES" "$B_URLS"
echo "B done: ${B_MS}ms useful=$B_USEFUL"

# ---------- C: Nitter instances ----------
echo "--- C: Nitter ---"
START=$(date +%s%N)
C_CODES=""
C_USEFUL=false
C_STATUS=""
C_NOTES=""
C_URLS=""
C_RESPONDING=""
QUERIES=("WoW%20Forever%20beta%20key" "from%3Awindows%20Forever" "WoW%20Forever%20beta%20code")
INSTANCES=("nitter.privacydev.net" "nitter.poast.org" "xcancel.com" "nitter.cz" "nitter.fdn.fr" "nitter.net")
for inst in "${INSTANCES[@]}"; do
  for q in "${QUERIES[@]}"; do
    url="https://${inst}/search?f=tweets&q=${q}"
    fname="$RAW/nitter_${inst}_$(echo "$q" | md5sum | cut -c1-6).html"
    http=$(curl -sS -L -A "$UA" -w '%{http_code}' -o "$fname" --max-time 12 "$url" 2>/dev/null || echo "000")
    C_STATUS="${C_STATUS}${inst}:${http},"
    if [[ "$http" == "200" ]]; then
      C_RESPONDING="${C_RESPONDING}${inst};"
      C_USEFUL=true  # responding counts as useful infrastructure
      found=$(extract_codes "$fname" "$url" | tr '\n' '|' | sed 's/|$//')
      if [[ -n "$found" ]]; then
        C_CODES="${C_CODES}${found}|"
      fi
      if grep -qiE 'forever|beta.?key|beta.?code' "$fname" 2>/dev/null; then
        C_NOTES="${C_NOTES}${inst}:content;"
      fi
    fi
    C_URLS="${C_URLS}${url}|"
  done
done
C_MS=$(time_ms "$START")
C_CODES=$(echo "$C_CODES" | sed 's/|$//')
C_URLS=$(echo "$C_URLS" | head -c 2000)
C_NOTES="responding=${C_RESPONDING} statuses=${C_STATUS}${C_NOTES}"
# Only mark useful if we got 200 + content OR codes
if [[ -z "$C_RESPONDING" ]]; then C_USEFUL=false; fi
log_method "C" "Nitter X search" "$C_MS" "$C_USEFUL" "$C_STATUS" "$C_NOTES" "$C_CODES" "nitter_multi"
echo "C done: ${C_MS}ms useful=$C_USEFUL responding=$C_RESPONDING"

# ---------- D: Direct x.com curl ----------
echo "--- D: x.com direct ---"
START=$(date +%s%N)
D_URL="https://x.com/search?q=WoW%20Forever%20beta%20key&src=typed_query&f=live"
fname="$RAW/xcom_search.html"
http=$(curl -sS -L -A "$UA" -w '%{http_code}' -o "$fname" --max-time 15 "$D_URL" 2>/dev/null || echo "000")
D_MS=$(time_ms "$START")
D_CODES=$(extract_codes "$fname" "$D_URL" | tr '\n' '|' | sed 's/|$//')
D_USEFUL=false
D_NOTES="likely_blocked_or_js_shell"
if [[ "$http" == "200" ]] && grep -qiE 'forever|timeline' "$fname" 2>/dev/null; then
  D_NOTES="got_html_may_be_js_shell"
fi
if [[ -n "$D_CODES" ]]; then D_USEFUL=true; fi
# Also try twitter.com
START2=$(date +%s%N)
fname2="$RAW/twitter_search.html"
http2=$(curl -sS -L -A "$UA" -w '%{http_code}' -o "$fname2" --max-time 15 \
  "https://twitter.com/search?q=WoW%20Forever%20beta%20key&f=live" 2>/dev/null || echo "000")
D2_MS=$(time_ms "$START2")
D_NOTES="${D_NOTES}; twitter.com=${http2} in ${D2_MS}ms; x.com=${http} in ${D_MS}ms"
TOTAL_D=$(( D_MS > D2_MS ? D_MS + D2_MS : D_MS + D2_MS ))
# Use wall for both sequentially already done — report combined
D_COMBINED=$(python3 -c "print($D_MS + $D2_MS)")
log_method "D" "Direct x.com/twitter curl" "$D_COMBINED" "$D_USEFUL" "${http},${http2}" "$D_NOTES" "$D_CODES" "$D_URL"
echo "D done: ${D_COMBINED}ms useful=$D_USEFUL http=$http/$http2"

# ---------- E: RSS/Atom ----------
echo "--- E: RSS/Atom ---"
START=$(date +%s%N)
E_CODES=""
E_USEFUL=false
E_STATUS=""
E_NOTES=""
E_URLS=""
for url in \
  "https://news.blizzard.com/en-us/rss" \
  "https://www.wowhead.com/news/rss" \
  "https://www.wowhead.com/news/tag/forever/rss" \
  "https://www.icy-veins.com/forums/forum/233-world-of-warcraft-rss.xml" \
  "https://www.mmo-champion.com/external.php?type=RSS2&forumids=20"
do
  fname="$RAW/rss_$(echo "$url" | md5sum | cut -c1-8).xml"
  http=$(curl -sS -L -A "$UA" -w '%{http_code}' -o "$fname" --max-time 15 "$url" 2>/dev/null || echo "000")
  E_STATUS="${E_STATUS}${http},"
  size=$(wc -c < "$fname" 2>/dev/null || echo 0)
  if [[ "$http" == "200" ]] && [[ "$size" -gt 100 ]]; then
    E_NOTES="${E_NOTES}ok:$url;"
    if grep -qiE 'forever|beta' "$fname" 2>/dev/null; then
      E_USEFUL=true
      E_NOTES="${E_NOTES}keyword;"
    fi
  fi
  found=$(extract_codes "$fname" "$url" | tr '\n' '|' | sed 's/|$//')
  if [[ -n "$found" ]]; then E_USEFUL=true; E_CODES="${E_CODES}${found}|"; fi
  E_URLS="${E_URLS}${url}|"
done
E_MS=$(time_ms "$START")
E_CODES=$(echo "$E_CODES" | sed 's/|$//')
log_method "E" "RSS/Atom feeds" "$E_MS" "$E_USEFUL" "$E_STATUS" "$E_NOTES" "$E_CODES" "$E_URLS"
echo "E done: ${E_MS}ms useful=$E_USEFUL"

echo "=== Core curl race done ==="
