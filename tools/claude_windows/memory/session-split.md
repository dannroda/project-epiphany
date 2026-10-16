---
name: session-split
description: How parallel Claude sessions split Epiphany work (2026-10-12) and the shared-file rule
metadata:
  node_type: memory
  type: project
  originSessionId: 6d9b9e44-5f38-4fea-9355-1ae9026939fc
  modified: 2026-10-12T01:01:47.447Z
---

Agreed with Daniel on 2026-10-12, after -04's code audit (38 tasks; commits a4b9f6e and d3f07ba):
- **Audit session:** audit bugs first. 11.79, 11.63, 11.64, 11.62 and 11.65 come before Daniel's big playtest.
- **Art session:** 12.17, 12.2, 12.12.
- **Overworld session:** 7.9, plus 11.88 and 11.82. Then 14.9 (SceneFlow), done *before* the fast-travel portals.

**Why:** several sessions edit the same files. The hotspots are save_manager.gd, player.gd, pit.gd, overworld.tscn and the terrain build/export scripts.

**How to apply:** one session per shared file at a time, and announce the commit to the others with SendMessage. Before closing a task, review it with the new godot-* skills (code-review, architecture, patterns, communication, data-driven). Related: [[commit-per-task]], [[nodes-in-tscn]].

Session names change when sessions restart (2026-10-12: art = -14, then -43 [fce16d], then -11, bugs = -68 then -fd, overworld = -1e). 2026-10-13: art = -11 [c00fbb] (sign messages as -11; after a restart peers see it as project-epiphany-5d [c113c0]), overworld = -eb [c4b3cf], design (dungeons, items, camera, D1 bosses) = -43 [a7e236]. If a name is unreachable, ListAgents and ask Daniel which is which; don't guess.
