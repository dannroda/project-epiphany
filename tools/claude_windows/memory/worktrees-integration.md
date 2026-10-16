---
name: worktrees-integration
description: since 2026-10-13 each session works in its own git worktree/branch; -fd (bugs session) integrates everything into main
metadata:
  node_type: memory
  type: project
  originSessionId: 288582ff-f0fb-4cb5-a598-45cacf4a334e
  modified: 2026-10-13T20:32:55.955Z
---

Daniel's rule (2026-10-13): parallel sessions work in git worktrees, not in the shared main tree, so they stop colliding with each other and with Daniel's editor (which reimports and touches files in the main tree). Sessions agree among themselves whether they share a worktree or not. When a session finishes something on its branch, it notifies **project-epiphany-fd** (the bugs/audit session), which integrates it into main.

**Why:** a shared index and tree swept other sessions' files into commits, and opening the editor changed files under the sessions' feet.

**How to apply:**
- Worktrees go in `../epiphany-wt/<name>` (a symlink to /home/ssd_disk/epiphany-wt since 2026-10-13: /home was at 96%; never move the main repo, it broke every session last time) on a branch `wt/<name>`. The first time, run `godot --headless --path <wt> --import` there; never open the editor in a worktree.
- Commit board changes (compass/tasks/*.json) in the branch. On a merge conflict in docs/tareas.md, take either side and regenerate it with `scompass export md`.
- When I (-fd) integrate: in the main tree, `git merge --no-ff wt/<name>` (Daniel's uncommitted changes stay as long as they don't touch the same files; if they do, stop and ask). Run the suite or the relevant tests, then tell the session to rebase onto main.
- Everything runs in the worktree, not just commits: headless godot (tests, debug/tmp tools like screenshots), Blender builds, exporters. debug/tmp is untracked, so sessions copy what they need. The main tree is only for Daniel's editor and my merges/tests.
- debug/tmp in every worktree is a symlink to main's debug/tmp (Daniel wants the temp files local in main). New worktree: `ln -s /home/drod/Proyectos/Godot/project-epiphany/debug/tmp debug/tmp` + `git update-index --skip-worktree debug/tmp/.gdignore`; `/debug/tmp` and `/debug/tmp.old/` are in the shared info/exclude. First import: copy main's .godot into the worktree, then `--import` (a cold import crashed).
- Integrating: before every `--import` in main, check `pgrep -fa "4.8-dev7/godot -e"`. If Daniel's editor is open, don't import or restore files: use the editor bridge (curl localhost:4713/scan) and tell him. On 2026-10-13 I imported while it was open (19:11). After importing, the reimported .res/kits come back modified: `git restore` them (same size, only the bytes change).
- I also work in my own worktree (../epiphany-wt/bugs, wt/bugs), not in main.

Supersedes the shared-tree parts of [[session-split]], [[no-early-staging]] and [[check-staging-before-commit]] (those still apply to the main tree, where Daniel works).


Pushing: GitHub rejects packs over 2 GB, so a big backlog goes in batches (`git push origin <sha>:refs/heads/main` along first-parent). Since 2026-10-13 (11.126) the history has no file over 100 MB; the pre-filter backup was deleted after the push (gc left .git at 2.5 GB).
