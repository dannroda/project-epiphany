---
name: sword-trail-elemental
description: Sword trail/slash styling is parked; demo_tajo.tscn was a test bed for future elemental attacks
metadata:
  node_type: memory
  type: project
  originSessionId: 164c1d90-fbc8-437b-bcd4-3fb1eab41c01
  modified: 2026-10-14T06:33:46.632Z
---

The sword slash work (12.27) is parked as of 2026-10-14. The player keeps the original Trail3D. src/world/vfx/demo_tajo.tscn (Trail3D at mid-blade + sword_trail.gdshader with a `fade` uniform, plus the unused tajo.gdshader crescent plane) was Daniel's test bed for possible **elemental attacks** (fire/ice/etc. sword variants).

Board card: 12.28 "Ataques elementales" (Paused, unassigned).

**Why:** Daniel said "es un avance, queda para después, la idea era testear para posibles ataques elementales".
**How to apply:** don't put the slash on the player unless asked. When elemental attacks come up, start from demo_tajo + sword_trail.gdshader. Known Trail3D gotchas: when it stops emitting it freezes its last points (needs the `fade` uniform, then clear()). In billboard mode UV.x is 0 at the blade and 1 at the tail end, and UV.y is 0 at the hilt and 1 at the tip. A custom shader with skip_vertex_transform must transform VERTEX itself.
