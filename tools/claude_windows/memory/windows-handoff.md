---
name: windows-handoff
description: "Daniel dual-boots into Windows with one Claude session on wt/windows; when merging it, read tools/claude_windows/HANDOFF.md; refresh the kit (export_kit.sh) before he boots Windows"
metadata:
  node_type: memory
  type: project
  originSessionId: 288582ff-f0fb-4cb5-a598-45cacf4a334e
  modified: 2026-10-16T05:34:19.404Z
---

Since 2026-10-16, Daniel can continue on Windows with the kit in `tools/claude_windows/`:
- `setup.ps1` clones the repos, creates the worktree `epiphany-wt\windows` on branch `wt/windows`, and copies the Claude profile (skills, settings without the Linux hooks) and the memory snapshot.
- `measure_shaders.ps1` runs the D3D12 shader baker measurement.

**How to apply (integrator):**
- Before he reboots into Windows, run `tools/claude_windows/export_kit.sh` so the memory snapshot is current. Then commit and push it through the usual merge.
- When he comes back, merge `wt/windows` like any peer branch: run the editor check first, then the full suite.
- Then read `tools/claude_windows/HANDOFF.md`. Apply its board changes and new memories, and reset the file to its empty sections.
- The Windows session can't message anyone, because the Linux sessions are off.

Related: [[worktree-per-session]], [[worktrees-integration]], [[compass-in-main]].
