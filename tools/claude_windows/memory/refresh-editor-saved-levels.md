---
name: refresh-editor-saved-levels
description: la_walls refresh on editor-saved levels writes bad diffs (headless nulls shader params; repack freezes instance-child props); edit colors by hand
metadata:
  node_type: memory
  type: feedback
  originSessionId: 164c1d90-fbc8-437b-bcd4-3fb1eab41c01
  modified: 2026-10-14T23:00:38.407Z
---

When a level was last saved by Daniel's editor, `la_walls refresh` produces a bad diff:
- With `--headless`, it writes `shader_parameter/... = null` on the cutaway material.
- Without headless, it still adds about 40 ext_resources and about 600 lines, writing the properties of instanced children explicitly (torches, doors, pots). That freezes their values in the level.

**Why:** in 12.34 (2026-10-14) the templo refresh would have overwritten Daniel's editor version (see [[editor-version-wins]]).

**How to apply:** for color or light changes (LOOKS ambient, sun, floor_color), edit the few lines by hand: templo.tscn `ambient_light_color`, Sun `light_color`, and the kit's `shader_parameter/floor_color`. Also update LOOKS so later refreshes match. Only refresh for real layout or piece changes, never with --headless, and send the diff to -fd before merging. Related: [[refresh-drops-instance-overrides]].
