---
name: refresh-levels-after-rebase
description: la_walls bake/refresh rewrites whole level .tscn; rebase wt/art onto latest main right before running it and send right away
metadata:
  node_type: memory
  type: feedback
  originSessionId: 164c1d90-fbc8-437b-bcd4-3fb1eab41c01
  modified: 2026-10-14T04:02:15.960Z
---

la_walls bake/refresh re-saves the entire level .tscn (chullpa, quenoa, totora, cumbre). -43 (design) edits those same levels in parallel, so a refresh done on an old base silently drops their newer changes when -fd merges (2026-10-14: 12.24 merge lost -43's gates/feather island/Rellano patch, quenoa had an undeclared ExtResource, portals/push_block/dungeon_reach tests broke).

**Why:** the text merge of two regenerated .tscn files can't keep both sides.

**How to apply:** right before any la_walls refresh/bake, `git rebase main` (after -fd confirms main is clean), refresh, test, commit only that, and send to -fd immediately; tell -43 which levels you're regenerating so they hold edits. See [[worktree-per-session]], [[editor-resave-drops-overrides]].
