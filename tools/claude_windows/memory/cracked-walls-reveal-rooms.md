---
name: cracked-walls-reveal-rooms
description: "Dungeon rule — a cracked wall always opens onto a full room of any kind (even one needed to finish the dungeon), never a one-cell niche with a chest; none in D1"
metadata:
  node_type: memory
  type: feedback
  originSessionId: e6055377-7849-42cf-b56b-a007f8b96d63
  modified: 2026-10-14T19:06:45.335Z
---

Daniel, 2026-10-14: in dungeons, cracked walls reveal rooms. Never a little square with a chest. The room can be any kind (chest + enemies was only an example), even one required to solve the dungeon. And no cracked walls at all in the first dungeon (Chullpa).

**Why:** the Rellano niche (one cell, bomb chest behind a crack) looked bad and made no sense; the veil/roof hacks to hide niches (11.137, 11.164) were the symptom.

**How to apply:**
- When designing or reviewing a dungeon, the space behind a cracked wall is its own room (own Area3D, camera framing, ≥22×14).
- Existing niches behind cracked walls (Queñoa OjosCrackedWall, temple CombinedCrackedWall) must become rooms or go.

See [[boss-key-backtracking]] and [[dungeon-chain]].
