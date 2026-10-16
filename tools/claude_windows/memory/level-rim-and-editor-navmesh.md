---
name: level-rim-and-editor-navmesh
description: "every floor of every LA level has a \"Pared LA x\" rim one cell outside the outer walls; navmeshes rebaked after any layout change, editor-equivalent"
metadata:
  node_type: memory
  type: project
  originSessionId: 288582ff-f0fb-4cb5-a598-45cacf4a334e
  modified: 2026-10-14T22:14:33.126Z
---

Daniel (2026-10-14, b18d2ea7 templo): rim on the level's "roof" = ring of "Pared LA x" GridMap cells (y 0) one cell outside the outer wall outline, then navmesh rebaked with the editor's Bake NavigationMesh. Must hold on every floor of every level. Same day I added it to all floors of chullpa, quenoa, totora, cumbre (48bebfcf) and rebaked.

Rim rule (reproduces his templo ring exactly, debug/tmp/fd/rim.py `rim2`): empty cells outside the layout (flood fill) that touch a wall cell (8-neighbours), minus cells 4-adjacent to a floor cell, minus a 5-wide strip in front of each exterior door ("Paso") so the doorway mouth stays open. Add cells by appending triplets to the GridMap `cells` line (text patch), not by repacking the scene.

Navmesh: `tools/bake_overworld_nav.gd -- <level>` gave byte-identical output to Daniel's editor bake on templo, so it is fine to use; the "wrong navmesh" problem was stale bakes after layout changes. Always rebake after touching a level's layout, and never commit a layout change without its rebake.

**How to apply:** new floors get the rim; refreshes must keep it. Related: [[editor-churn-discard]], [[la-walls-baked-levels]], [[refresh-levels-after-rebase]].
