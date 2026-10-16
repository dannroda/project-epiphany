---
name: boss-key-backtracking
description: "Dungeon rule — the boss key needs some backtracking with the dungeon item, and the critical path must cross most of the dungeon"
metadata:
  node_type: memory
  type: feedback
  originSessionId: e6055377-7849-42cf-b56b-a007f8b96d63
  modified: 2026-10-14T17:49:34.968Z
---

General rule for every dungeon (Daniel, 2026-10-14): getting the boss key takes some backtracking. After the item, you go back to rooms you already visited and use it there. The boss key never sits next to the boss on the way forward.

**Why:** in the Chullpa you could skip 90% of the dungeon. The weight-plate pot was in the Rellano itself, so the locked door, the small key and the whole basement were optional, and the boss key sat right before the boss.

**How to apply:**
- When designing or reviewing a dungeon graph, check what is mandatory: the small keys and their puzzles have to sit on the critical path.
- The boss key goes in an early area that needs the item, so the player has to come back.
- Look at what the minimal path skips, not just whether the dungeon can be finished (test_dungeon_reach only checks the latter).

See [[dungeon-chain]] and [[boss-rooms-rule]].
