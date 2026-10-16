---
name: commit-per-task
description: "In Epiphany, commit as soon as a board task is finished — without asking"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 6d9b9e44-5f38-4fea-9355-1ae9026939fc
  modified: 2026-10-08T04:41:29.367Z
---

When a compass/ task is finished (moved to done), commit right away, without asking. Only the files of that task, and in compass/ only the files I changed (another session may be loading tasks for other milestones at the same time).

**Why:** The user said "recuerda que cada vez que se termine una tarea se comitea" (2026-10-08).

**Board changes always get committed** (2026-10-11, "las tareas comitealas siempre, siempre"): any compass/ file I create or change (new tasks, moves, steps, links, notes) plus the regenerated docs/tareas.md go into a commit right away, even when no code task finished — never leave them untracked.

**How to apply:** Mark it done with scompass, then `git add` the specific files and commit; no co-author trailer ([[no-coauthor-trailer]]).
