---
name: la-walls-baked-levels
description: dungeons baked with LA doubled walls (chullpa since 15b5a3e8) — edit grid with normal kit items then run la_walls.gd refresh, never bake twice; tests must be room-relative
metadata:
  type: project
---

Since 2026-10-13 (task 12.18, art session) levels/chullpa.tscn is baked with tools/la_walls.gd: every wall line between rooms is doubled (each room its own 2 m wall), so rooms moved in world space and the grid uses data/kits/chullpa_la_kit.tres. The Queñoa gets the same next.

**Why:** Link's Awakening look Daniel approved in the debug/la test.
**How to apply:** when editing walls/doors of a baked dungeon, place the normal kit items (Pared/Puerta) and run `godot --headless --path . --script res://tools/la_walls.gd -- refresh` (re-picks LA pieces); never run `bake` again. Tests and scenarios must not use world coordinates: test_chullpa/test_quenoa use `_in("Floor/Room", local)` and scenarios use the scene's SpawnStart. Gameplay nodes keep their position relative to their room. Related: [[session-split]].
