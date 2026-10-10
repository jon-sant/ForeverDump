#!/usr/bin/env bash
# Re-fetch the upstream reference sources at the exact commits used (see docs/REFERENCES.md). Not needed normally:
# the trees are already in the repo. usage: fetch_reference.sh [DEST=../wowdev-upstream]
set -eo pipefail
DEST="${1:-../wowdev-upstream}"; mkdir -p "$DEST"
get() { # url dir commit
  [ -d "$DEST/$2/.git" ] || git init -q "$DEST/$2"
  git -C "$DEST/$2" fetch -q --depth 1 "$1" "$3" && git -C "$DEST/$2" checkout -q FETCH_HEAD && echo "$2 @ $3"
}
get https://github.com/Gethe/wow-ui-source.git wow-ui-source-forever 15666a6e67938a1ab5caf041406464251db111ca  # 1.60.1 (70245), branch forever
get https://github.com/Gethe/wow-ui-source.git wow-ui-source-live 09b9db7948abc9b9648dedaab51eb0cf3ee67b31     # 12.1.0.69933, branch live
get https://github.com/Gethe/wow-ui-source.git wow-ui-source-ptr a89e9d0ceb7f6cd31e8fc5ca7df1a338ac0b1b58      # branch ptr
get https://github.com/Ketho/BlizzardInterfaceResources.git BlizzardInterfaceResources-forever ec7e5ff11a3400cd67483f68ae59aadc0afe6a14  # 1.60.1 (70205)
get https://github.com/silverwind/idTip.git idTip 4df162c8dc82ad0223e3da79f6dcbc4753086bd6
get https://github.com/Thunderz96/forever-addon-kit.git forever-addon-kit 8dc297689059dd204bf8663a05aaa36d6a628b76
get https://github.com/wowdev/WoWDBDefs.git WoWDBDefs e3df3707b103342dd487b1f5ea0f9b1b63da4bbe
get https://github.com/Marlamin/DBC2CSV.git DBC2CSV 1e4aaa465b2d243963fa5c637a69bd607427e25a
get https://github.com/wowdev/TACTSharp.git TACTSharp de24db8794708fd40f98d8894a1a0a05593e3628
echo "Newer Forever builds: cd foreverdump && tools/refresh/refresh_all.sh (wago.tools DB2 CSV + CDN extract)."
