# ForeverDump 2.1.0 (WoW Forever, Interface 16001)

A one-stop API and runtime dumper for the WoW Forever client. It saves everything the client exposes to addons to
`WTF\Account\<ACCOUNT>\SavedVariables\ForeverDump.lua` for the box-side converter (`tools/fdump.py`).

Quick start: `/fdump logs macro`, put **FD_Logs** on a bar, click it once to capture everything, play, then click it again
(stops, saves and reloads). `/fdump secrets` shows the live secrets verifier panel.
`/fdump help` lists every command. See ADDON-USAGE.md (shipped next to this folder in the zip) for the run order,
the FD_Logs macro, the combat-log restriction and privacy notes.

Files: Core (config, safety, meta and project info), Legacy (v1 dump), BlizzardAddOns, Docs (APIDocumentation walk),
Globals, Widgets, World (templates, frames, addons), CVars, Protected, Extras, Recorder, CombatLog (Forever-safe
combat recorder), Errors (error handler chain or BugGrabber callbacks, blocked actions), Profiler, Logs (FD_Logs capture-everything toggle),
Probe, Secrets (secrets map and live verifier, getter sweep, panel), UI (copy window), Commands.

Safety: refuses heavy work in combat; works in frame-sliced chunks; never registers COMBAT_LOG_EVENT*; never calls
RegisterAllEvents; never does arithmetic or comparisons on secret values (they are recorded as `<secret>`);
`schemaVersion` is in the header; each section can be toggled and cleared. Untested in-game: please report errors
from `/fdump errors show`.
