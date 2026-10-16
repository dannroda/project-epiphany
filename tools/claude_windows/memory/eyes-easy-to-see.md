---
name: eyes-easy-to-see
description: "Arrow eyes (EyeSwitch) always go where they're easy to see — never on a south wall or down in a pit; check niches/chests are walkable"
metadata:
  node_type: memory
  type: feedback
  originSessionId: e6055377-7849-42cf-b56b-a007f8b96d63
  modified: 2026-10-15T05:28:39.586Z
---

Daniel, 2026-10-15 (Cumbre Ventisquero): "el ojo siempre tiene que estar donde se vea fácil". The eye sat on the south wall inside the abyss strip, hidden by the camera. Eyes only react to projectiles, so they don't need an abyss in front; put them on a north wall (identity basis, z = wall face + 0.6) or another clearly visible spot. In the same room a snow block (Muro) sat in front of the map niche's gate, making the chest unreachable; DungeonGraph reach is logical only and didn't catch it.

**Why:** a hidden eye reads as a missing puzzle; an unreachable chest is a softlock.

**How to apply:** when placing or reviewing eyes, never face them north on a south wall. After layout edits, check chest/gate fronts with a navmesh path (see test_cumbre snowdrift test).
