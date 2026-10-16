---
name: windowed-godot-secondary-monitor
description: "Windowed Godot runs (screenshots, renders, fps) go to the HP secondary monitor without stealing focus"
metadata:
  node_type: memory
  type: feedback
  originSessionId: e6055377-7849-42cf-b56b-a007f8b96d63
  modified: 2026-10-16T02:04:58.807Z
---

Daniel, 2026-10-16 (via -67): any windowed Godot run must open on the secondary HP monitor and not take his focus. Use `godot --display-driver x11 --screen 1 --path . ...` plus a temporary `override.cfg` in the worktree root containing `[display]` / `window/size/no_focus=true`, deleted afterwards. xvfb-run does not hide it (KDE on Wayland).

**Why:** windows popping on his main screen interrupt his work.

**How to apply:** wrap every room_shots/screenshot run this way; headless tests unchanged (still under bwrap, see [[tests-bwrap-gamepad]]).
