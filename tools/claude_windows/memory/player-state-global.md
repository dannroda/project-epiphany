---
name: player-state-global
description: "Player state (current health etc.) is global, never tied to the scene; it survives scene changes and goes in the save"
metadata:
  node_type: memory
  type: project
  originSessionId: 288582ff-f0fb-4cb5-a598-45cacf4a334e
  modified: 2026-10-12T00:27:17.432Z
---

The player's state (current health included) is global: it must not depend on the scene. Changing scene (mostly entering/leaving dungeons) keeps it, and the save stores it (current health is restored on load, not refilled). Decided by the user on 2026-10-11 (task 11.79).

**Why:** levels instance their own player, so anything read from the player node in `_ready` resets on every travel; the user saw hearts refilling as a bug.
**How to apply:** keep per-player state in GameState (indexed per player for co-op, see [[coop-direction]]), restore it on spawn, and include it in the save; only refill on new game, respawn after death, or a heart container.
