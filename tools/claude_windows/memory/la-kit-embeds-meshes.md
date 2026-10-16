---
name: la-kit-embeds-meshes
description: "data/kits/<style>_la_kit.tres embeds the wall meshes; after rebuilding paredes_la pieces, keep the kit diff from la_walls refresh"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 164c1d90-fbc8-437b-bcd4-3fb1eab41c01
  modified: 2026-10-14T18:45:17.861Z
---

The LA kits (data/kits/templo_la_kit.tres etc.) hold the wall meshes as embedded ArrayMesh sub-resources. After rebuilding the paredes_la pieces in Blender, the new geometry only reaches the game when `la_walls refresh <level>` rewrites the kit, so that kit diff must be committed. It is not noise.

**Why:** in 12.30 I restored templo_la_kit.tres thinking it was churn. The temple door passages kept the old ochre floor, and I had to refresh again.

**How to apply:** if the pieces did not change, the kit diff is noise; restore it as usual ([[refresh-levels-after-rebase]]). If build_paredes_la.py changed, keep the kit changes. Also, build_paredes_la.py can't build only one style: filtering the style loop republishes the other .glb files without their walls. Run the full build (it takes about 15 s), then restore the other styles' .glb, whose changes are only exporter noise.
