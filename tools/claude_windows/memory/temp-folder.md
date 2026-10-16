---
name: temp-folder
description: Session temporaries go in debug/tmp/ (git-ignored, .gdignore'd); temp/ is the user's own reference folder
metadata:
  type: feedback
---

Everything temporary (debug scripts, measurement scripts, screenshots, test worktrees' leftovers) goes in `debug/tmp/<topic>/` inside the project. `/debug/tmp/*` is in .gitignore and `debug/tmp/.gdignore` (tracked) keeps the editor from scanning it (no .uid files, not exported); `godot --script res://debug/tmp/...` still runs. Scratchpad stays fine for files that don't need res://.

**Why:** the user said "lo que sea temporal debería tener una carpeta fija y ser ignorado por git" (2026-10-11); the old debug/tmp_* folders kept showing up as untracked.

Since 2026-10-13 (Daniel, via -fd) every worktree's debug/tmp is a symlink to the main tree's debug/tmp, shared by all sessions: use subfolders named for your own work so sessions don't overwrite each other. Set up a new worktree with `ln -s /home/drod/Proyectos/Godot/project-epiphany/debug/tmp debug/tmp` + `git update-index --skip-worktree debug/tmp/.gdignore`. Each worktree's old copy stays in debug/tmp.old.

**How to apply:** never create debug/tmp_* or other ad-hoc folders; `temp/` at the root is the user's reference images (Mega Man ZX etc.) — don't put anything there. In --script tools, avoid class_name types that pull autoloads (they fail to compile before autoloads exist).
