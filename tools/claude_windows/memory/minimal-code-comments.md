---
name: minimal-code-comments
description: "In Epiphany code, keep comments to the bare minimum — no doc comments or explanatory inline comments"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 6d9b9e44-5f38-4fea-9355-1ae9026939fc
  modified: 2026-10-08T04:23:34.304Z
---

Keep code comments to a minimum in project-epiphany (GDScript, plugins). Only what is truly non-obvious (e.g. a thread-safety constraint, a workaround link); no `##` doc comments, no per-line explanations.

**Why:** The user asked for it explicitly while I was writing the debug/log plugin (2026-10-08).

**How to apply:** Explanations go in the chat reply, the GDD or the task notes, not in the code.
