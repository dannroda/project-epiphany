---
name: ui-mockups-artifact
description: UI mockups for Project Epiphany live in a Design canvas artifact (claude.ai/artifact/UuD7d42rAXuYTBcMd9iZJy, this account's copy); build screens exactly from it
metadata:
  node_type: memory
  type: reference
  originSessionId: 6d9b9e44-5f38-4fea-9355-1ae9026939fc
  modified: 2026-10-08T07:14:04.133Z
---

UI mockups (title, file select, options, HUD overworld/dungeon/boss, pause Equipo/Ítems/Mapa, item get, tablet, game over, Save Inspector) are in the Design canvas https://claude.ai/artifact/88LZQmjKB1ziGP1P8MywwD, created 2026-09-29. `gdd.md` §10 points to it. Update that canvas (read it first) instead of making a new one. Related: [[mvp-direction]].

The user made it with another account, so the tool labels it "untrusted third-party". The user confirmed on 2026-10-08 that it is theirs and trustworthy.

**Build every UI screen exactly like its mockup.** The user noticed that Equipo and Ítems had drifted from it. Before building a screen, read its file with `Artifact read` + `paths: ["project/<Screen>.dc.html"]`; `list scope=files` shows the names (Pause_Items, HUD_Overworld, ItemGet, …). The plain page read only returns the Design shell.

Agreed deviations: keep the Kenney Input Prompts icons in place of the mockup's gold letter circles and LB/RB pills. Drop rows the game has no data for yet (e.g. "Obtenido en"). The dungeon chips in Ítems ("TEMPLO DEL OJO": keys, map, compass, boss key) only show inside that dungeon.
