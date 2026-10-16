---
name: check-staging-before-commit
description: run git diff --cached --stat before committing; other sessions stage files (git rm) in the shared index
metadata:
  node_type: memory
  type: feedback
  originSessionId: e6055377-7849-42cf-b56b-a007f8b96d63
  modified: 2026-10-13T08:01:23.282Z
---

Before every commit, run `git diff --cached --stat` and unstage anything that isn't mine.

**Why:** parallel sessions share the same git index. On 2026-10-12 my commit ede16c1 swept in another session's staged `git rm src/ui/fader.*`, leaving HEAD with an autoload pointing at missing files.

**How to apply:** `git add` only my files, then check the cached stat lists exactly those before `git commit`. Also compare each file's line count in the cached stat with what I changed: on 2026-10-13 commit e34db47f swept in the art session's WIP on tools/la_walls.gd and levels/quenoa.tscn, written between my status check and my add (my change was 2 lines, the stat said 23). For a shared file (another session's tool or a level they bake), run `git diff <file>` right before adding, and if it has foreign hunks, add only mine with `git apply --cached` of a patch holding my hunks. Never chain `git diff --cached --stat && git add … && git commit` in one command: on 2026-10-13 that swept another session's staged deletions (water_la_*.tres) into cc301fde, because the stat printed but nothing stopped. Look at the stat first, then commit in a separate call. If foreign entries are staged, use `git commit --only <my paths>`, which leaves their staging alone. Related: [[session-split]], [[commit-per-task]].
