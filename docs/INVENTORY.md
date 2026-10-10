# Inventory: where everything came from (box paths at handoff time, 2026-10-10 ET)

| repo path | box source | notes |
|---|---|---|
| `foreverdump/` | `/workspace/foreverdump` | whole project; excluded only regenerable caches (HANDOFF.md §9) |
| `foreverdump/real/` | `/workspace/foreverdump/real` | runs 1-22 incl. 6b, raw |
| `foreverdump/ForeverDump-v*.zip` | same | every packaged build v2 .. v2.2.29 (there is no v2.2.5 zip). Copies at `/workspace/ForeverDump-v2.2.*.zip` were byte-identical and are not duplicated |
| `kth/` | `/workspace/kth` | KTH port: original (CurseForge file 7908947, All Rights Reserved licence), baseline, port (git history in bundle), tests, tools, bgdiag*, dm, run16.pkl |
| `kth/releases/` | `/workspace/KillTheHealer-Forever-*.zip` | baseline + forever.2 .. forever.12 (incl. 9b) |
| `foreverdump-research/` | `/workspace/foreverdump-research` | secrecy research + guide prototype (its `.venv` dropped; requirements-research.txt) |
| `idtip-wowforever/` | `/workspace/idtip-wowforever` | idTip Forever patch + build |
| `captures/user-uploads/` | `/home/box/agent-data/agents/a70ef7fb-.../attachments` | all 154 uploads verbatim (sha256 file names); index `captures/UPLOADS-INDEX.tsv` |
| `workspace-root/` | `/workspace/HSM-STATUS.md`, `SECRETS-GUIDE.{html,md}` | Oct 9 20:40 versions (older than foreverdump/docs/) |
| `other/wow-forever-keyhunt/` | `/workspace/wow-forever-keyhunt` | Sept 2026 Forever beta-key giveaway pollers + metrics; not part of the addon work |
| `_git-bundles/` | nested `.git` dirs | 17 bundles, INDEX.tsv |
| `MEMORY.md` | agent memory + project record | see its header |

Not found on the box / not included:
- The agent's server-side memory store is not a file on the box (MEMORY.md section B is filled by the parent agent).
- No Grok Build project/memory files existed before this handoff; AGENTS.md / GROK.md are new.
- No `requirements.txt` existed: the Python tools are standard-library only (python 3.8+; box had 3.13.5).
- Lua toolchain is system packages (lua5.1 5.1.5, luacheck 1.2.0, busted 2.2.0, lua-filesystem 1.8.0), not vendored.
- `/workspace/LEADS-v2215.md` = `foreverdump/docs/LEADS-v2215.md` (identical).
