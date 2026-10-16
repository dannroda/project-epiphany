---
name: editor-resave-drops-overrides
description: "the open editor's resave of overworld.tscn can silently drop instance overrides; diff semantically before committing"
metadata:
  node_type: memory
  type: project
  originSessionId: 6d9b9e44-5f38-4fea-9355-1ae9026939fc
  modified: 2026-10-13T20:21:34.995Z
---

When the open Godot editor resaves overworld.tscn (Daniel hits Play), it can drop overrides on instanced children. In 43fab275 that lost RavineBridge's Model scale and its 13 m collider, and the bridge broke without any visible diff noise beyond reordering.

**Why:** the editor's resave reorders nodes and adds unique_ids, so the raw git diff is huge and hides real losses.

It kept happening even after reloads (the 4.8 dev editor drops `parent="X" index="N"` child overrides of that instance), so the fix was moving them into their own inherited scene (src/world/ravine_bridge.tscn, 2026-10-13). Prefer an inherited scene over child overrides in overworld.tscn.

**How to apply:** before committing overworld.tscn, run `python3 debug/tmp/ow2/tscn_diff.py <base> WT` (node/sub_resource/property comparison). Ignore LOSTPROP entries that are defaults (kind 1 = CAVE, amount 1, roughness 1.0, box size 1). Related: [[editor-bridge]], [[session-split]].
