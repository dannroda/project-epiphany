---
name: dungeon-gridmap-cells
description: Dungeon/cave GridMaps center their cells and sit at (-1,0,-1) since 11.157; convert cells with local_to_map/map_to_local, never cell*2
metadata:
  type: project
---
Since 11.157 (2026-10-14) the dungeon, cave and test-level GridMaps have cell_center_x/z = true and transform origin (-1, 0, -1). World positions did not change (cell c is still centered at world 2c), but the local math did.

**Why:** -fd aligned the tiles with the editor grid. Hand-written `cell * 2` in tools and tests silently breaks against the new local frame.

**How to apply:** in code and tests, convert with `grid.local_to_map(grid.to_local(p))` and `grid.to_global(grid.map_to_local(c))`. In the .tscn, the cell triples are unchanged. Related: [[la-walls-baked-levels]].
