---
name: tests-bwrap-gamepad
description: "Run headless Godot tests under bwrap hiding /dev/input — Daniel's physical gamepad feeds input into them"
metadata:
  node_type: memory
  type: project
  originSessionId: e6055377-7849-42cf-b56b-a007f8b96d63
  modified: 2026-10-15T21:40:19.210Z
---

Daniel's connected gamepad leaks input into headless test runs (mass failures, player stuck Attacking). Run the suite as `bwrap --dev-bind / / --tmpfs /dev/input godot --headless --path . --script res://tests/run_tests.gd -- …` (-fd, 2026-10-15).

Also: a test failure that prints an old dialogue/translation text is usually a stale import in .godot, not a missing commit — `godot --headless --path . --import` then `git checkout assets/ data/kits/`.
