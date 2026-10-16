---
name: boss-rooms-rule
description: "Sub-boss and boss fights happen in rooms without obstacles (only pots and the like); the dungeon item's chest sits in an adjacent room that opens only when the sub-boss is beaten"
metadata:
  node_type: memory
  type: project
  originSessionId: e6055377-7849-42cf-b56b-a007f8b96d63
  modified: 2026-10-12T22:01:25.266Z
---

Daniel, 2026-10-12: sub-boss and boss fights always take place in rooms without obstacles: no holes, niches, inner walls or blocks, only objects like pots. The chest with the dungeon's item goes in an adjacent room that opens only by beating the sub-boss, not in a niche inside the sub-boss's room.

**Why:** that's how Zelda dungeons are built. Daniel saw D1 with the bow in a niche inside the warden's lair, which also had a hole.

**How to apply:** when designing or reviewing a dungeon, check:
- the sub-boss and boss rooms have no obstacles;
- the item's room is reached only through a door wired to the fight (an EyeFight or a wave as its switch).

The dungeon graph has to reflect it. Goes with [[dungeon-chain]].
