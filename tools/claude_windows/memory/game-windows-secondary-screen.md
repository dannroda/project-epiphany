---
name: game-windows-secondary-screen
description: "any windowed Godot run (screenshots, renders, fps) goes on the HP 1920x1080 secondary screen without taking focus; xvfb-run does NOT hide it (Wayland)"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 288582ff-f0fb-4cb5-a598-45cacf4a334e
  modified: 2026-10-16T02:04:39.153Z
---

Every windowed game/tool run opens on the HP monitor (HDMI-A-1, left, 1920x1080) and never takes Daniel's focus:

`/opt/godot/versions/4.8-beta1/godot --display-driver x11 --screen 1 --path . ...` plus a temporary `override.cfg` in the worktree root with `[display]` / `window/size/no_focus=true` (delete it after the run).

Under X11 (XWayland, DISPLAY=:0) screen 0 is the main 2560x1440 (DP-3) and screen 1 is the HP; verified 2026-10-15.

**Why:** Daniel (2026-10-15): windows must not pull him out of what he's doing. `xvfb-run` doesn't help: KDE Wayland is active and Godot picks Wayland and opens on his main screen anyway.

**How to apply:** use this for screenshots, render comparisons and fps probes; headless tests stay headless (under bwrap, see [[tests-bwrap-gamepad]]). Tell new peer sessions too.
