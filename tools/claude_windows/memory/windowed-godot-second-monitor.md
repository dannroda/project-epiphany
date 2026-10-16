---
name: windowed-godot-second-monitor
description: "Windowed Godot runs (captures, renders, fps) go on Daniel's secondary HP monitor without taking focus"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 164c1d90-fbc8-437b-bcd4-3fb1eab41c01
  modified: 2026-10-16T02:04:55.187Z
---

Any windowed Godot run (screenshots, renders, fps) must open on the secondary HP monitor and must not steal Daniel's focus. Use `godot --display-driver x11 --screen 1 --path . ...` (under X11, screen 1 = HP 1920x1080) plus a temporary `override.cfg` in the worktree root with `[display]` / `window/size/no_focus=true`; delete it afterwards. xvfb-run does not hide it (KDE is on Wayland). Headless tests are unchanged. Blender: same idea, don't take focus.

**Why:** Daniel's rule (relayed by -67, 2026-10-15): captures were popping up on his main screen while he works.

**How to apply:** every capture script run with the renderer; merge the `[display]` section with any other temporary override (e.g. the contact-shadow settings) and remove the file when done. Related: [[headless-tests-gamepad]].
