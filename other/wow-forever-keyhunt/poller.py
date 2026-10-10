#!/usr/bin/env python3
import re, time
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timedelta, timezone
from pathlib import Path
import requests

BASE = 'https://arctic-shift.photon-reddit.com/api'
SUBREDDITS = ('wow', 'classicwow', 'australian')
POST_URL = BASE + '/posts/search'
COMMENT_URL = BASE + '/comments/search'
LINK_ID = '1wik331'
OUT = Path('/workspace/wow-forever-keyhunt/codes-live.txt')
SKIP = {'CVK5F4DMNBGJBFF6HLWQW'}
RAW_RE = re.compile(r'(?<![A-Z0-9])([A-Z0-9]{21})(?![A-Z0-9])')
HYPHEN_RE = re.compile(r'(?<![A-Z0-9])([A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{5}-[A-Z0-9]{4}-[A-Z0-9]{4})(?![A-Z0-9])')
KEYWORDS = ('forever', 'mymacca', 'maccas', 'beta')
HEADERS = {'User-Agent': 'wow-forever-keyhunt/1.0 (public Arctic Shift API)'}


def iso(dt):
    return dt.astimezone(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')


def get_json(url, params):
    try:
        r = requests.get(url, params=params, headers=HEADERS, timeout=20)
        if r.status_code != 200:
            return []
        obj = r.json()
        data = obj.get('data') if isinstance(obj, dict) else None
        return data if isinstance(data, list) else []
    except Exception:
        return []


def post_task(subreddit, after):
    return ('post', get_json(POST_URL, {
        'subreddit': subreddit, 'after': iso(after), 'sort': 'desc', 'limit': 100,
        'fields': 'id,title,selftext,created_utc,subreddit,url'
    }))


def comment_task(after):
    return ('comment', get_json(COMMENT_URL, {
        'link_id': LINK_ID, 'after': iso(after), 'sort': 'desc', 'limit': 100,
        'fields': 'id,body,created_utc,subreddit,link_id,parent_id'
    }))


def post_source(x):
    u = x.get('url') or ''
    return u if u.startswith('http') and '/comments/' in u else f"https://www.reddit.com/r/{x.get('subreddit','')}/comments/{x.get('id','')}/"


def comment_source(x):
    return f"https://www.reddit.com/r/{x.get('subreddit','wow')}/comments/{x.get('link_id', LINK_ID)}/_/{x.get('id','')}/"


def normalized_codes(text):
    found = set(RAW_RE.findall(text.upper()))
    found |= {x.replace('-', '') for x in HYPHEN_RE.findall(text.upper())}
    return found


def main():
    known = set(SKIP)
    try:
        known |= normalized_codes(OUT.read_text(errors='ignore'))
    except OSError:
        pass
    emitted = []
    last_wave = None
    with ThreadPoolExecutor(max_workers=4) as pool:
        for wave in range(8):
            wave_start = datetime.now(timezone.utc)
            last_wave = wave_start
            after = wave_start - timedelta(minutes=11)
            futures = [pool.submit(post_task, s, after) for s in SUBREDDITS]
            futures.append(pool.submit(comment_task, after))
            results = []
            for f in as_completed(futures):
                try:
                    results.append(f.result())
                except Exception:
                    pass
            candidates = []
            for typ, rows in results:
                for x in rows:
                    try:
                        age = (datetime.now(timezone.utc).timestamp() - float(x.get('created_utc'))) / 60.0
                    except (TypeError, ValueError):
                        continue
                    if age < 0 or age >= 10:
                        continue
                    if typ == 'post':
                        text = ((x.get('title') or '') + '\n' + (x.get('selftext') or ''))
                        if not any(k in text.lower() for k in KEYWORDS):
                            continue
                        source = post_source(x)
                    else:
                        text = x.get('body') or ''
                        source = comment_source(x)
                    for raw in normalized_codes(text):
                        if raw in known:
                            continue
                        known.add(raw)
                        candidates.append((raw, age, source))
            for raw, age, source in sorted(candidates, key=lambda z: z[1]):
                code = f'{raw[:4]}-{raw[4:8]}-{raw[8:13]}-{raw[13:17]}-{raw[17:21]}'
                line = f'{code} | age: {age:.1f}m | source: {source}'
                print(line, flush=True)
                emitted.append(line)
                with OUT.open('a', encoding='utf-8') as fh:
                    fh.write(line + '\n')
            if wave < 7:
                time.sleep(max(0.0, 15.0 - (datetime.now(timezone.utc) - wave_start).total_seconds()))
    if not emitted:
        et = last_wave.astimezone(timezone(timedelta(hours=-4))).strftime('%Y-%m-%d %I:%M %p ET')
        line = f'NO_FRESH + last wave {et}'
        print(line, flush=True)
        with OUT.open('a', encoding='utf-8') as fh:
            fh.write(line + '\n')

if __name__ == '__main__':
    main()
