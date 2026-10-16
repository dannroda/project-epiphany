---
name: compass-user-changes
description: uncommitted compass/ changes no session made are Daniel's (dashboard use or a scompass upgrade); commit them
metadata:
  type: feedback
---

Daniel (2026-10-14): anything in compass/ that no session modified comes from him, either from using the dashboard (playtest results, notes, moves) or from upgrading scompass, which regenerates files such as compass/AGENTS.md.

**Why:** -fd kept leaving those diffs uncommitted, unsure whose they were.

**How to apply:** treat them as board changes and commit them in main (re-export docs/tareas.md with the CLI first), like any other board change. Don't discard them as editor churn. Related: [[compass-in-main]], [[commit-per-task]], [[editor-churn-discard]].
