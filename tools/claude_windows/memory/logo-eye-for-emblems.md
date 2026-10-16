---
name: logo-eye-for-emblems
description: "emblem/ornament details on models (plates, badges, carved symbols) use the Epiphany logo eye (epi.logo_eye), not the chakana"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 164c1d90-fbc8-437b-bcd4-3fb1eab41c01
  modified: 2026-10-15T17:23:22.231Z
---

Daniel (2026-10-15): "siempre que estén este tipo detalles, usa el ojo del logo". Said about a gold chakana plate on a model's loincloth, after asking for the logo eye on the hammer like the final boss's hands.

**Why:** the logo eye is the game's signature mark, and he wants it repeated on ornaments.

**How to apply:**
- Ornamental emblems on models and props (badges on chests, belts or pedestals, carved faces of weapons) use `epi.logo_eye(p, center, width, depth, iris=(swatch, shade))` instead of `epi.chakana_plate`.
- The iris uses the owner's color: neon for good or golden things, doom for enemies.
- Exception: a symbol with a gameplay meaning stays. Example: the BLOCK floor plate shows the push block's chakana because it is the same relief as the block.
