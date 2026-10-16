---
name: navmesh-and-rim-daniel
description: "Rebake navmesh with every layout change (bake_overworld_nav.gd matches the editor); every dungeon floor keeps the outer \"Pared LA x\" rim; editor saves win"
metadata:
  node_type: memory
  type: feedback
  originSessionId: e6055377-7849-42cf-b56b-a007f8b96d63
  modified: 2026-10-14T22:14:48.618Z
---

Daniel, 2026-10-14 (relayed by -fd, corrected the same day):
- Navmesh: the bad navmeshes were stale bakes. tools/bake_overworld_nav.gd gives byte-identical output to the editor's Bake NavigationMesh on templo, so it's fine to use. After any layout change, rebake and commit the rebake together with the change.
- Rim: every floor of every LA level has a ring of "Pared LA x" cells at y 0, one cell outside the outer walls (main 48bebfcf: chullpa, quenoa, totora, cumbre, templo). Rule to keep or generate it: empty outside cells touching a wall (8 neighbours), minus cells next to floor (4 neighbours), minus a 5-wide strip in front of exterior "Paso" doors. la_walls refreshes must keep it unchanged, and new floors need it.
- What his editor saves wins over our versions. Don't restore what he committed. Warn -fd before sending a refresh that would change his levels.

**How to apply:**
- Before any refresh, diff the rim and outer walls.
- Rebake the navmesh after layout edits.

See [[refresh-levels-after-rebase]] and [[editor-resave-drops-overrides]].
