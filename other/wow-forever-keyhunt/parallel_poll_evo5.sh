#!/usr/bin/env bash
# Evolution 5: parallel free mirror polls
set -u
DIR=/workspace/wow-forever-keyhunt
LOG=$DIR/evolution-5-parallel.jsonl
LIVE=$DIR/codes-live.txt
UA='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/128.0.0.0 Safari/537.36'
KEYRE='[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4,5}-[A-Z0-9]{4}-[A-Z0-9]{4}|[A-Z0-9]{20,22}'
NOW=$(date -Is)
echo "{\"event\":\"wave_start\",\"ts\":\"$NOW\"}" >> "$LOG"

urls=(
  "https://reddit.sentinel-team.org/posts/1wik331/"
  "https://www.ozbargain.com.au/node/975129"
  "https://www.frugalfeeds.com.au/2026/mcdonalds-australia-offers-world-of-warcraft-forever-beta-key-for-1000-mymaccas-points/"
  "https://www.icy-veins.com/wow-forever/news/players-are-earning-wow-forever-beta-codes-by-buying-australians-mcdonalds/"
  "https://www.mmo-champion.com/content/14536-Warcraft-Forever-Collection-Giveaway"
)

fetch_one() {
  local url="$1"
  local start end ms status body
  body=$(mktemp)
  start=$(date +%s%3N)
  status=$(curl -sS -L --max-time 10 -A "$UA" -o "$body" -w '%{http_code}' "$url" 2>/dev/null || echo 000)
  end=$(date +%s%3N)
  ms=$((end-start))
  # extract candidate codes (filter placeholders)
  local hits
  hits=$(grep -oE "$KEYRE" "$body" 2>/dev/null | grep -viE 'XXXX|YYYY|0000|TEST|ARKOSE|EXAMPLE' | sort -u | head -20 | tr '\n' ',' | sed 's/,$//')
  echo "{\"url\":\"$url\",\"ms\":$ms,\"status\":\"$status\",\"hits\":\"$hits\"}" >> "$LOG"
  if [[ -n "$hits" ]]; then
    echo "$hits" | tr ',' '\n' | while read -r c; do
      [[ -z "$c" ]] && continue
      # age unknown from static pages — mark as age:unknown-static (hunters must verify)
      echo "$(date -Is) | $c | age:unknown-needs-verify | source: $url" >> "$LIVE"
    done
  fi
  rm -f "$body"
  echo "$ms $status $url hits=${hits:-none}"
}

# parallel
pids=()
for u in "${urls[@]}"; do
  fetch_one "$u" &
  pids+=($!)
done
for p in "${pids[@]}"; do wait "$p" || true; done
echo "{\"event\":\"wave_end\",\"ts\":\"$(date -Is)\"}" >> "$LOG"
echo "--- live file ---"
tail -n 20 "$LIVE" 2>/dev/null || echo "(empty)"
