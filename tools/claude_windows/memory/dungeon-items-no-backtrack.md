---
name: dungeon-items-no-backtrack
description: Design rule — an item obtained in dungeon N never unlocks new content inside earlier dungeons
metadata:
  node_type: memory
  type: feedback
  originSessionId: 6d9b9e44-5f38-4fea-9355-1ae9026939fc
  modified: 2026-10-11T18:22:58.493Z
---

An item obtained in a dungeon never unlocks new things inside a previous dungeon. Example: if the jump feather comes from dungeon 2, dungeon 1 must not have a chest (or any gate) that needs the feather.

**Why:** the user stated this as a design rule (2026-10-11), while 11.35 (feather) was being designed.

**How to apply:**
- When placing a gate or chest that needs an item, check which dungeon gives that item. The gate goes only in that dungeon, in later dungeons, or in the overworld.
- Previous dungeons stay closed once they are finished.
- The overworld is not "earlier": the user confirmed it works like a hub. New items from dungeons or caves are meant to open things and new paths there.

Related: [[mvp-direction]]
