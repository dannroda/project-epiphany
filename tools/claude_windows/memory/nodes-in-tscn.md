---
name: nodes-in-tscn
description: "Anything that inherits Node goes in the .tscn, never created by code; feel values are tuned by the user by eye"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 6d9b9e44-5f38-4fea-9355-1ae9026939fc
  modified: 2026-10-11T06:11:45.499Z
---

If it inherits from Node (meshes, trails, particles, lights, areas, timers, masks…), it lives in the .tscn, not `X.new()` + `add_child` in a script. Code may only adjust what truly depends on runtime data (e.g. trail width fitted to the equipped weapon), with the look-tunable properties left on the node.

**Why:** the user tunes feel/visuals (trails, VFX, timings) by eye in the inspector; asking Claude for those tweaks makes no sense and code-built nodes can't be retouched. (2026-10-11, after the sword trail was built in player.gd.)

**How to apply:** new features put their nodes in scenes (instantiable sub-scenes for things spawned at runtime, e.g. projectiles with their Trail3D); expose feel numbers as node properties or @export so they're editable. Extends [[ui-scenes-and-state-machine]] (UI already had this rule).
