---
name: headless-tests-gamepad
description: Daniel's gamepad feeds input into headless test runs; hide /dev/input with bwrap
metadata:
  type: reference
---

Daniel's connected gamepad sends input into headless Godot tests, which can make them flaky. Run them with `bwrap --dev-bind / / --tmpfs /dev/input godot --headless …` (tip from -fd, 2026-10-15).
