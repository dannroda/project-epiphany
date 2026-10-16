---
name: compass-in-main
description: "The Scope Compass board is always managed in the main tree, never judged from a worktree's copy"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 6d9b9e44-5f38-4fea-9355-1ae9026939fc
  modified: 2026-10-14T18:02:31.449Z
---

The board (`compass/`, `docs/tareas.md`) is always managed in main (Daniel, 2026-10-14: "el Compass siempre se maneja en main"). The hub, the Godot dock and the web view all read the main tree. A worktree's `compass/` can be stale: it may be missing schemas such as playtest.schema.json, new columns (Paused) and other sessions' edits.

**Why:** I told Daniel the Epiphany had no playtest schema because I was looking at my worktree. Main already had it.

**How to apply:**
- To read the board (statuses, schemas, playtests, what's pending), use the main tree: `node ../scope-compass/hub/bin/scompass.js --dir /home/drod/Proyectos/Godot/project-epiphany …`.
- Before writing anything to the board from a worktree, bring main in first.
- New cards: ask -fd to create them in main; never `scompass add` in a worktree. On 2026-10-14 my 11.175 collided with one -fd had created in main, and mine became 11.176. Steps, notes and moves on my own cards can still be done in the worktree, after merging main.

See [[task-board-artifact]] and [[worktrees-integration]].
