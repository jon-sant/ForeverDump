#!/usr/bin/env bash
set -u
OUT=/workspace/wow-forever-keyhunt/evolution-1-race.jsonl
CODES=/workspace/wow-forever-keyhunt/codes-found.txt
: > "$OUT"
: > "$CODES"
UA='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36'
KEYRE='[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}(-[A-Z0-9]{4})?'

time_fetch() {
  local name="$1" url="$2"
  local start end ms bodyfile status hits
  bodyfile=$(mktemp)
  start=$(date +%s%3N)
  status=$(curl -sS -L --max-time 12 -A "$UA" -o "$bodyfile" -w '%{http_code}' "$url" 2>/dev/null || echo 000)
  end=$(date +%s%3N)
  ms=$((end-start))
  hits=$(grep -oE "$KEYRE" "$bodyfile" 2>/dev/null | head -20 | tr '\n' ' ')
  # filter placeholders
  hits=$(echo "$hits" | grep -oE "$KEYRE" | grep -viE 'XXXX|YYYY|ZZZZ|0000|TEST' | head -10 | tr '\n' ',' | sed 's/,$//')
  if [[ -n "$hits" ]]; then
    echo "$hits" | tr ',' '\n' | while read -r c; do
      [[ -n "$c" ]] && echo "$c | $name | $url" >> "$CODES"
    done
  fi
  printf '{"method":"%s","ms":%s,"status":"%s","hits":"%s","url":"%s"}\n' "$name" "$ms" "$status" "$hits" "$url" | tee -a "$OUT"
  rm -f "$bodyfile"
}

echo "=== EVOLUTION 1 BASELINE RACE $(date -Is) ==="
time_fetch "reddit_classicwow_new" "https://www.reddit.com/r/classicwow/new.json?limit=50"
time_fetch "reddit_wow_new" "https://www.reddit.com/r/wow/new.json?limit=50"
time_fetch "reddit_search_forever_key" "https://www.reddit.com/search.json?q=WoW+Forever+beta+(key+OR+code)&sort=new&limit=50"
time_fetch "reddit_search_mymacca" "https://www.reddit.com/search.json?q=MyMacca+Forever+beta+code&sort=new&limit=25"
time_fetch "nitter_privacydev" "https://nitter.privacydev.net/search?f=tweets&q=WoW+Forever+beta+key"
time_fetch "nitter_poast" "https://nitter.poast.org/search?f=tweets&q=WoW+Forever+beta+key"
time_fetch "xcancel_search" "https://xcancel.com/search?f=tweets&q=WoW+Forever+beta+key"
time_fetch "x_com_search" "https://x.com/search?q=WoW%20Forever%20beta%20key&f=live"
time_fetch "blizzard_news" "https://news.blizzard.com/en-us/world-of-warcraft"
time_fetch "icy_veins_maccas" "https://www.icy-veins.com/wow-forever/news/players-are-earning-wow-forever-beta-codes-by-buying-australians-mcdonalds/"
time_fetch "mmo_champ" "https://www.mmo-champion.com/content/"

echo "--- RANKED BY ms ---"
sort -t: -k2 -n /workspace/wow-forever-keyhunt/evolution-1-race.jsonl 2>/dev/null || true
# proper sort by ms field
python3 - <<'PY'
import json,re
rows=[]
for line in open('/workspace/wow-forever-keyhunt/evolution-1-race.jsonl'):
    line=line.strip()
    if not line.startswith('{'): continue
    rows.append(json.loads(line))
rows.sort(key=lambda r: r['ms'])
print('\nRANKED (fastest first):')
for r in rows:
    print(f"  {r['ms']:5d}ms  status={r['status']}  hits={r['hits'] or '-'}  {r['method']}")
print('\nCODES FILE:')
print(open('/workspace/wow-forever-keyhunt/codes-found.txt').read() or '(none)')
PY
