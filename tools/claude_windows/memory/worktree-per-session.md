---
name: worktree-per-session
description: "which worktree each session uses and its current name (names change on restart → roll call); never commit to main; the integrator merges"
metadata:
  node_type: memory
  type: project
  originSessionId: 164c1d90-fbc8-437b-bcd4-3fb1eab41c01
  modified: 2026-10-13T20:34:53.213Z
---

The worktree each session uses under the rule in [[worktrees-integration]] (since 2026-10-13):
- Integrator + bugs (-fd, then -67 since the 2026-10-15 restart): `/home/ssd_disk/epiphany-wt/bugs`, branch `wt/bugs`; merges into main.
- Overworld session (-eb, then -d6): `../epiphany-wt/overworld`, branch `wt/overworld`.
- Art session (-11 / -5d, then -39): `/home/drod/Proyectos/Godot/epiphany-wt/art`, branch `wt/art`.
- Design (-43, then -05): `../epiphany-wt/design`, branch `wt/design`.

Session names change on every PC restart: after one, run a roll call (Daniel asked for it) so each one says its role and signs with its new name. No session commits to main; the integrator merges.

**Why:** Daniel's rule, so sessions stop colliding with each other and with the editor in the main tree.

**How to apply:** run builds, bakes, tests and shots inside your own worktree path. debug/tmp is ignored by git, so copy any helpers you need into the worktree's debug/tmp. Daniel only sees a change after -fd merges it into main, so tell him that instead of "reload from disk".
