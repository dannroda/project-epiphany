---
name: blender-palette-addon-shadow
description: "Blender's installed epiphany_palette addon is a symlink to MAIN's tools/blender; in a worktree, palette edits need `blender -b --factory-startup`"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 164c1d90-fbc8-437b-bcd4-3fb1eab41c01
  modified: 2026-10-14T22:57:15.757Z
---

~/.config/blender/5.2/scripts/addons/epiphany_palette.py is a symlink to the main tree's tools/blender/epiphany_palette.py. Blender loads it as an addon at startup, so `import epiphany_palette` in worktree build scripts gets main's version, not the worktree's.

**Why:** in 12.34 make_palette.py silently rebuilt palette.png from main's old swatches, so the change didn't show up.

**How to apply:** when a worktree changes epiphany_palette.py (swatch colors or order), run make_palette.py and the build_* scripts with `blender -b --factory-startup -P ...`. Don't edit the symlink. Related: [[worktrees-integration]].
