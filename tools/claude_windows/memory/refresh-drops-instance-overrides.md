---
name: refresh-drops-instance-overrides
description: la_walls refresh (PackedScene.pack) drops overrides on children of non-editable instances; put such variants in an inherited .tscn
metadata:
  node_type: memory
  type: feedback
  originSessionId: 164c1d90-fbc8-437b-bcd4-3fb1eab41c01
  modified: 2026-10-14T18:47:08.568Z
---

A la_walls refresh or bake packs the whole level again. Overrides on children of non-editable instances are lost in that repack. For example, a `[node name="Model" parent=".../Mallqui/Body"] mesh = ...` override in chullpa.tscn disappeared silently.

**Why:** the Chullpa boss went back to the plain mummy model after the refresh in 0de3bb4d. Daniel saw it as "the mini-boss but bigger" (12.31).

**How to apply:** to give a level instance a different look or child setup, make an inherited scene (like src/entities/mummy_guard/mallqui.tscn) and instance that. Don't override child nodes in the level. Related: [[editor-resave-drops-overrides]], [[la-walls-baked-levels]].

2026-10-14 (12.34, -5d): on a level Daniel saved from the editor, a refresh makes a bad diff the other way. Headless, it nulls the cutaway shader params. With rendering it adds ~40 ext_resources and ~600 lines writing instance-child props explicitly (torches, doors, pots), which freezes them. Fixed the same day (a067d2e9): refresh instantiates with edit state (only real overrides written), keeps the outer rim, and refuses to run headless; run it with the renderer (`godot --path . --script res://tools/la_walls.gd -- refresh <level>`). Still check its diff semantically before merging; see [[editor-churn-discard]], [[level-rim-and-editor-navmesh]].
