---
name: coop-direction
description: "Co-op Four Swords-style planned (local M13, then online M14); new code must not assume a single player"
metadata:
  node_type: memory
  type: project
  originSessionId: 164c1d90-fbc8-437b-bcd4-3fb1eab41c01
  modified: 2026-10-13T08:20:28.456Z
---

Decided 2026-10-10: Four Swords-style co-op after the MVP — local first (milestone M13), then online with host authority (M14). Recorded in gdd.md §13/§14.

**Why:** the user wants co-op; every system written assuming "the" player makes the later refactor more expensive.

**Paused 2026-10-11:** the user put co-op on hold for now (the multi-floor dungeon was the first thing designed around it). Keep not assuming one player, but don't block designs on co-op questions.

**2026-10-13:** "Multiplayer no vamos a tocar": don't pick or work M13/M14 tasks (co-op bugs included) unless the user asks.

**How to apply:** when writing or touching gameplay code (enemies, camera, rooms, HUD, items, cutscenes), get the players list or the AI's target instead of `get_first_node_in_group("player")`; the full refactor of existing code is task 13.1. Related: [[mvp-direction]].
