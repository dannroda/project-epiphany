---
name: scope-compass
description: "Scope Compass = the user's own project-management app for game dev (born from the Epiphany task board); repo ../scope-compass, own board artifact JAiu8ZznTSLcDk8EzU3Zaj"
metadata:
  type: project
---

Scope Compass is the user's own app (CLI `scompass` + Node hub + web UI + Godot dock) that replaces the artifact task boards. Repo: `git@github.com:dannroda/scope-compass.git`, working copy at `/home/drod/Proyectos/Godot/scope-compass` (sibling of project-epiphany). Initialized 2026-09-29 (pushed to origin/main): `docs/spec.md` (sections have `<!-- id -->`), `docs/decisiones.md` (D1–D9, append-only), `schema/`, `hub/`, `web/`, `addons/scope_compass/`, `tools/` (Python prototypes), `compass/` (its own board data), `project.godot` (repo opens in Godot).

Its plan lives in its own board artifact https://claude.ai/artifact/JAiu8ZznTSLcDk8EzU3Zaj (milestones M0–M7), with the same git-copy rule as Epiphany: after board changes, regenerate `compass/` and `docs/tareas.md` (`tools/artifact_to_md.py --title "Scope Compass" --board <url>`).

**Why:** the user wants data in git with the app optional; stack Node chosen over all-Godot because phone access is a requirement (D4, reopen if that changes).
**How to apply:** record new decisions as new D-entries in `docs/decisiones.md`; keep spec paths consistent with the actual repo layout. Related: [[task-board-artifact]].
