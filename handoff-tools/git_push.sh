#!/usr/bin/env bash
# Initialise the repo and push in batches (GitHub: 100 MB/file hard limit, ~2 GB per push).
# usage: git_push.sh <git-remote-url> [--lfs]
#   default: plain git (largest committed file 75.8 MB; GitHub warns above 50 MB but accepts)
#   --lfs:   track big SVs/logs with Git LFS (.gitattributes.lfs); GitHub free LFS = 1 GB storage/bandwidth, the
#            captures are ~2 GB -> needs a data pack.
set -eo pipefail
cd "$(dirname "$0")/.."
URL="$1"; [ -n "$URL" ] || { echo "usage: $0 <remote-url> [--lfs]"; exit 2; }
[ -d .git ] || git init -q -b main
if [ "${2:-}" = "--lfs" ]; then git lfs install; cp .gitattributes.lfs .gitattributes; git add .gitattributes; fi
git remote get-url origin >/dev/null 2>&1 || git remote add origin "$URL"
batch() { git add -- "$@"; git diff --cached --quiet || { git commit -q -m "handoff: $1"; git push -q -u origin main; echo "pushed: $1"; }; }
batch README.md HANDOFF.md AGENTS.md GROK.md MEMORY.md MANIFEST.tsv .gitignore .gitattributes* requirements-research.txt docs handoff-tools _git-bundles workspace-root
batch foreverdump/ForeverDump foreverdump/tools foreverdump/tests foreverdump/docs foreverdump/fixtures foreverdump/*.md foreverdump/.luacheckrc foreverdump/.work foreverdump/out
batch foreverdump/ref foreverdump/data foreverdump/.cache
batch foreverdump/*.zip
batch kth foreverdump-research idtip-wowforever
for d in foreverdump/real/*/; do batch "$d"; done
batch captures
batch other
batch .
git status --short | head
