---
name: setting-undecided
description: "Andean setting not final (cyber-shinobi / Megaman Zero option); player stays the previous low-poly model; toon restyles of it were rejected"
metadata:
  node_type: memory
  type: project
  originSessionId: 164c1d90-fbc8-437b-bcd4-3fb1eab41c01
  modified: 2026-10-10T23:39:59.310Z
---

As of 2026-10-10 the user is unsure about the Andean "Altiplano del Ojo" setting; the current player model is a first version. They're exploring a cyberpunk-shinobi alternative in the spirit of Megaman Zero (energy sabers and pistols), with a candidate player design: black curly hair with buns, red eyes, black hood with wide sleeves, red obi sash.

Player model, 2026-10-11: the user went back to the previous low-poly player (build_personajes.jugador, Zero-inspired red armor), which the game still uses. Tried and dropped the same day: a Wind Waker chibi restyle ("muy infantil, parece una caricatura") and 2D design sheets in Megaman ZX proportions ("no me estás entendiendo"). Don't push a player restyle again unless the user asks; if they do, ask for their own reference first instead of iterating on guesses. The toon cyber-shinobi (build_shinobi.py + shared tools/blender/toon.py) and the cel shader (ToonToggle, key 4) stay, the shinobi for a later part of the game.

Reference the user gave for what they mean (2026-10-11): temp/ModelOXAile.{obj,fbx,dae} + textures and temp/Custom _ Edited - Mega Man Zero _ ZX Customs.../ (Vent armorless + Model F/H/L/P/X/ZX forms, same base body with swappable armor), Megaman ZX game models (Capcom IP: reference only, never ship or copy it). Traits: 1.55 m, ~4.5 heads (chin 1.2, shoulder 1.11, waist 0.97, hip 0.72 wide, knee 0.47, boot top 0.36), slim body, faceted hard-surface armor with crisp edges, hand-painted textures with soft gradients and the face (eyes, mouth) painted in a texture, alpha-card hair, ~15k tris, saturated red/navy/white/gold. My attempts missed it by being round primitives with flat palette colors and chibi (or 2D sheets the user didn't want).

Status 2026-10-11 end of day: ZX-style player attempt paused ("es un avance, pero sigue sin gustarme. Dejémoslo para otro día"), saved as WIP in tools/blender/build_jugador.py (commit 9fc4a91, board m12-12 step 9). The aesthetic target is the reference look applied to the CURRENT player design, not a copy of Capcom designs. Next session focus moved to touching up the current low-poly player and the shinobi test scene.

**Why:** the art direction may pivot, so Andean-specific work could be thrown away.

**How to apply:** keep gameplay code and data setting-agnostic (no Andean names baked into logic); prefer reskinnable palette/piece pipelines; don't over-invest in Andean-only assets without checking. Related: [[mvp-direction]].
