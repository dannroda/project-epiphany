---
name: editor-bridge
description: "Drive the user's open Godot editor via the Editor Bridge plugin (curl localhost:4713) instead of asking them to focus/click"
metadata:
  node_type: memory
  type: reference
  originSessionId: 6d9b9e44-5f38-4fea-9355-1ae9026939fc
  modified: 2026-10-08T06:41:10.734Z
---

The user keeps the Godot editor open on Epiphany. Never launch a second editor instance (`--editor`, `--import`) or `git stash` while it is open. Use the Editor Bridge plugin (`addons/editor_bridge/`, task 0.13) instead of asking the user:

- `curl -s localhost:4713/ping` — check it's up.
- `curl -s -X POST localhost:4713/scan` — after creating/deleting scripts or resources: registers `class_name`s, UIDs, imports (waits for `script_classes_updated`).
- `curl -s -X POST "localhost:4713/reload_plugin?name=epiphany_tools"` — after editing that plugin's scripts.
- `play[?scene=res://…]`, `stop`, `status`, `log?since=<seq>` (editor output + the game's Log tab lines), `open?path=…&line=N`, `save`, `plugin?name=…&enabled=…`, `autoload` (name, path), `setting` (name, value) — the last two use the editor API so project.godot isn't clobbered.

Third crash (2026-10-08, SIGSEGV in Godot core): `/run` opened enemy.tscn right after I overwrote enemy_bt.tres and changed enemy.gd on disk. Rule of thumb: when a task changes scripts or resources that open scenes use, ask the user to close the editor and work on disk (text edits for .tscn; avoid repacking scenes with PackedScene.pack, which drops UIDs and bakes runtime state); use `/run` only for small edits when nothing those scenes depend on changed.

The user may reopen the editor mid-task (e.g. to add assets); it then overwrites scenes I edited on disk with its older in-memory copy (this broke task 3.1's pause_menu.tscn). Right before committing, re-check that my scene edits are still in the files (grep the node names) and have tests assert on the nodes a script uses.

Headless `ResourceSaver.save()` over an existing resource drops the `uid=` from its header (and from ext_resources), which breaks UID references elsewhere. After a headless resave, restore the old UID with `ResourceSaver.set_uid(path, ResourceUID.text_to_id(old))` (take it from `git show HEAD:<file>`) and check that `godot --headless --quit-after 60` prints no "invalid UID".

NEVER call `Script.reload()` inside the editor (via `/run`) on a script that has live instances (e.g. enemy.gd with skeletons open): it segfaulted the editor (2026-10-08). When the editor is closed, editing .tscn on disk is safe; check `pgrep -f 4.8-dev7/godot` first. `/run` can execute twice (re-entrant `_process` while a scene opens): make run scripts idempotent.

2026-10-08: the editor crashed (SIGABRT, segfault, no symbols) right as I ran `scan` after adding new class_names and changing `damage_info.gd`, a script used by resources the Save Inspector had loaded. Cause unconfirmed. Prefer headless `--script` for generating data and tests; call `scan` only when the editor really needs the new classes, and tell the user if it crashes.

Changes to the bridge itself still need the user to toggle "Editor Bridge" in Plugins. Headless `godot --headless --script` runs (tests: `res://tests/run_tests.gd`) are fine alongside the open editor.
