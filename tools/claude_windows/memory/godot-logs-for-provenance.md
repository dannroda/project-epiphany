---
name: godot-logs-for-provenance
description: "when unexplained changes show up in main, check the Godot logs (timestamps) before asking peers"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 288582ff-f0fb-4cb5-a598-45cacf4a334e
  modified: 2026-10-14T19:34:17.165Z
---

When files change in main and I don't know where they came from, look at the Godot logs first: their file names and modification times show when an editor or game was opened, which can be matched against the files' mtimes. Logs are in `~/.local/share/godot/app_userdata/Project Epiphany/logs/` (`godot<ISO date>.log`; check the other app_userdata folders too if the time doesn't match). Headless test runs also write logs there and rotation keeps only a few, so look before running tests.

**Why:** 2026-10-14 an old-style la_walls rewrite of 4 LA kits and chullpa.tscn in main turned out to be Daniel opening the editor; I asked all three peer sessions instead of checking the logs.
**How to apply:** compare file mtimes (`ls -l --time-style=+%H:%M`) with the log timestamps; an editor opening right before the change means editor resave churn (see [[editor-churn-discard]], [[editor-resave-drops-overrides]]).
