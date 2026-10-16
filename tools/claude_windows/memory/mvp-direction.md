---
name: mvp-direction
description: "Project Epiphany evolved past the GWJ97 jam GDD: MVP = small overworld + one full Zelda-style dungeon; decisions taken 2026-09-29"
metadata:
  type: project
---

The current GDD is `gdd.md` (renamed from the jam GDD on 2026-09-29; tasks live in the task board artifact, see [[task-board-artifact]]; `ai/tasks/` is LimboAI's default custom task dir, keep it for BT scripts only). Decisions as of 2026-09-29:
- MVP = a small overworld + one full dungeon, with as many Zelda mechanics as possible (not just sword + shield). Dungeon item unlocks the rest of the dungeon; items spread across the overworld.
- No currency, but items exist. Inventory with two screens: player gear (sword, shield, armor/clothes) and secondary items/weapons (potions, bow/arrows). Multiple swords or elemental sword powers still undecided.
- Save system required early (debug first), to iterate the data architecture on.
- Camera: `levels/test.tscn` is considered overworld (follow camera). In dungeon rooms the camera follows the player clamped to room bounds and animates on door transitions.
- Z-target stays (user added it post-jam, plus more modern movement). Known gap: can't switch targets, always picks the closest. Also wants aiming with the right stick / mouse.
- Physics RigidBody boxes in the test level are intentional (testing physics for enemies / remotely-affected blocks), not a bug.
- User wants to refactor the player, mainly to fit the inventory system.

**How to apply:** Plan against this scope, not the jam's 7-day scope. Related: [[limboai-patched-build]].
