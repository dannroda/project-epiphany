---
name: task-board-artifact
description: "Project Epiphany tasks live in compass/ (Scope Compass format, source of truth since 2026-09-29); edit via the scompass CLI; the old artifact board is archived"
metadata:
  type: reference
---

Epiphany's task board is `compass/` in the repo (milestones/*.json, tasks/*.json, schema/, config.json with hub port 4712). It is the source of truth; the artifact https://claude.ai/artifact/DPeQdjQUUsQv7zCz7Tu5aY is archived (stale, don't write to it).

Edit with the Scope Compass CLI from the repo root: `node ../scope-compass/hub/bin/scompass.js <cmd>` (list, show, add, set --file - --etag, step add/set/rm, check, move, refs check, restart). If the hub is running, writes go through it and reach the Godot dock and web UI live; `docs/tareas.md` is regenerated automatically. Always pass `--etag` on writes: the user edits tasks concurrently from the dock.

Step format: `text` = one short line (always visible), optional `detail` = how/why/files (collapsed behind ▸). Detail may link GDD sections as `[[gdd#id]]`; keep `refs check` clean.

**Why:** the user works only inside the Godot editor (no external IDE, Godot can't render markdown); tasks must be manageable with git alone, and they read them in the Scope Compass dock. See [[scope-compass]].
**How to apply:** never hand-edit docs/tareas.md; commit compass/ changes together with the related code when the user asks to commit.
