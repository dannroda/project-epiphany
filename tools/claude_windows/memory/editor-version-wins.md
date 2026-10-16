---
name: editor-version-wins
description: Daniel's editor saves of levels/kits/door .res win over regenerated ones; keep the outer Pared LA x rim; layout changes ship with their navmesh rebake; ask -fd first
metadata:
  node_type: memory
  type: feedback
  originSessionId: 164c1d90-fbc8-437b-bcd4-3fb1eab41c01
  modified: 2026-10-14T22:14:46.587Z
---

On 2026-10-14, Daniel committed his editor saves of templo, chullpa, their kits and the llave/madera door .res files (main 97627968 "Tweaks"). His rule: the editor's version wins over what our tools regenerate. He also says our tools build the NavigationMesh wrong.

**Why:** the editor's output is the reference version. A la_walls refresh or a piece rebuild overwrites his levels, navmesh and doors.

Since b18d2ea7, the templo GridMap has a ring of "Pared LA x" cells one cell outside the outer walls, and it must be kept. The same rule applies to all levels and floors. Since 48bebfcf every dungeon floor has that rim. Navmesh, corrected by -fd: tools/bake_overworld_nav.gd matches the editor bake exactly, so a layout change must be committed together with its rebake.

**How to apply:** rebase onto main before any refresh. If a refresh or build changes his levels, navmesh or door .res files, check with -fd before sending it. Don't silently overwrite them. Related: [[refresh-levels-after-rebase]], [[la-kit-embeds-meshes]], [[editor-churn-discard]].
