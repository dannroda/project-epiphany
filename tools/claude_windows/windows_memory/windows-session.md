---
name: windows-session
description: "On Windows (dual boot) there is ONE session: it works in wt/windows, pushes that branch, and the Linux integrator merges; Linux paths/tools in other memories have Windows equivalents here"
metadata:
  type: project
---

Daniel dual-boots. When Claude runs on Windows it is a single session, and the Linux sessions are not running (the PC is booted into Windows). So there is nobody to message, no roll call, and no integrator online.

**Role:** Windows tester. This covers the D3D12/Vulkan builds, shader baker, pipeline stutter, and anything Windows-only. It does bug fixes too if Daniel asks.

**Where to work:** the worktree `..\epiphany-wt\windows`, branch `wt/windows`, made by `tools\claude_windows\setup.ps1`. The main clone is read-only for this session: it never commits to main and never merges.
- Commit on wt/windows following [[commit-per-task]] and [[no-coauthor-trailer]], then `git push origin wt/windows`.
- Back on Linux, the integrator merges it and runs the full suite.

**Board:** it is read-only here, because the integrator manages it in main ([[compass-in-main]]). Findings, measurements and "please update card X" go in `tools/claude_windows/HANDOFF.md` on wt/windows. The Linux integrator reads that file on merge and updates the board.

**Windows equivalents of Linux-only rules in other memories:**
- **Godot:** the path is in [[windows-machine]] (written by setup.ps1). Use it wherever a memory says `/opt/godot/versions/4.8-beta1/godot`.
- **Tests:** there is no bwrap, which [[tests-bwrap-gamepad]] relies on, so ask Daniel to unplug or turn off the gamepad before a headless run. Command: `& $godot --headless --path . --script res://tests/run_tests.gd -- --jobs=4`.
- **Windowed runs** ([[game-windows-secondary-screen]]): the same `override.cfg` with `[display]` / `window/size/no_focus=true`, plus `--screen N`. On Windows the screen index of the HP monitor is not known yet. Check it once by printing `DisplayServer.get_screen_count()` and each `screen_get_position`/`screen_get_size`, then record it in [[windows-machine]].
- **Things that don't exist here:** paths under `/home/...`, `/opt/...` and `/home/ssd_disk/...`, the Blender MCP setup, and `/home/ssd_disk/LA_export`. Ask Daniel if one is needed.
- **Memory:** the memory files here are a snapshot from Linux, copied by the kit. New memories written on Windows also go in HANDOFF.md, so the Linux side can add them to its own memory.
