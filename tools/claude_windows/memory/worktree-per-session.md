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
- Integrator + bugs (-fd, then -67, -cb since 2026-10-16): `/home/ssd_disk/epiphany-wt/bugs`, branch `wt/bugs`; merges into main.
- Overworld session (-eb, -d6, then -5d since 2026-10-16): `../epiphany-wt/overworld`, branch `wt/overworld`.
- Art session (-11 / -5d, -39, then -dd since 2026-10-16): `/home/drod/Proyectos/Godot/epiphany-wt/art`, branch `wt/art`.
- Design (-43, -05, then -aa since 2026-10-16): `../epiphany-wt/design`, branch `wt/design`.

Session names change on every PC restart: after one, run a roll call (Daniel asked for it) so each one says its role and signs with its new name. No session commits to main; the integrator merges.

**Why:** Daniel's rule, so sessions stop colliding with each other and with the editor in the main tree.

**How to apply:** run builds, bakes, tests and shots inside your own worktree path. debug/tmp is ignored by git, so copy any helpers you need into the worktree's debug/tmp. Daniel only sees a change after -fd merges it into main, so tell him that instead of "reload from disk".
