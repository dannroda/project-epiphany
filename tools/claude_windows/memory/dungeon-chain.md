---
name: dungeon-chain
description: dungeon/item chain (D1 Chullpa feather, D2 Queñoa bow since 2026-10-13) and the per-dungeon item + sub-boss rule
metadata:
  node_type: memory
  type: project
  originSessionId: e6055377-7849-42cf-b56b-a007f8b96d63
  modified: 2026-10-12T20:42:36.432Z
---

Chain (Daniel, 2026-10-12, task 11.113; D1/D2 swapped 2026-10-13 because the feather plays better as the first dungeon item): D1 feather (Chullpa, id/flags ch_), D2 bow (La Queñoa Vigía, qv_), D3 hookshot, D4 mirror shield (Cumbre), then the eye temple is the LAST dungeon and must use every item (its flags keep the old d1_ prefix). Power gloves are out. Flag prefixes are per dungeon, not per number, so reordering never needs renames.

Rule for every dungeon: its item is guarded by a sub-boss based on that dungeon's boss, beatable WITHOUT the item (earlier items allowed). The second half of the dungeon is solved with the item, combined with earlier dungeons' items. Example: the Queñoa (D2) second half combines bow and feather jumps; the Chullpa (D1) has no earlier dungeon item, only bombs.

**Why:** the eye boss was conceived as a demo ending, so it fits as the game finale.
**How to apply:** design and graph every dungeon this way; keeps [[dungeon-items-no-backtrack]]. Overworld session (-eb, [[session-split]]) adapts gating in the 7.10 sketch.
