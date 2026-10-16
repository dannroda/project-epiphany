---
name: model-exploration-no-swap
description: Character restyles are exploration; never swap the in-game player model unless the user says so
metadata:
  node_type: memory
  type: feedback
  originSessionId: 164c1d90-fbc8-437b-bcd4-3fb1eab41c01
  modified: 2026-10-11T03:56:24.009Z
---

When trying new character looks (toon player, shinobi, realism), build them as separate files and show renders; don't point the game (tools/build_character_models.gd SOURCES) at the new model or regenerate src/entities/models/jugador.tscn with it. User, 2026-10-11: "no lo reemplaces a menos que te diga. estamos explorando".

**Why:** they're still deciding the art direction and didn't want the game changed by an experiment.

**How to apply:** compare in scratch renders or a test scene (like levels/test_shinobi.tscn); swap only on explicit OK. Related: [[setting-undecided]].
