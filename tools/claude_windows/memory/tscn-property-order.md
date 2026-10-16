---
name: tscn-property-order
description: "In .tscn, script-exported properties written before `script =` are silently dropped on load; --script tools must not statically type game classes that use autoloads"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 164c1d90-fbc8-437b-bcd4-3fb1eab41c01
  modified: 2026-10-12T21:52:53.020Z
---

When hand-editing a .tscn, put exported (script) properties AFTER the `script = ExtResource(...)` line. Properties written before it are silently lost on load. This happened in Oct 2026: quenoa/chullpa TopDownCamera `offset` never applied, so the game used the default camera; the design session fixed it in ef5151d8.

**Why:** Godot applies node properties in file order, so before the script is attached those properties don't exist yet.

**How to apply:**
- After editing a scene by hand, verify the value by instantiating it, not by reading the file.
- In `godot --script` tools, don't statically type game classes such as TopDownCamera. Classes that use autoloads (Players, GameState) fail to compile at that point with "Identifier not found". Use `set()` or `"prop" in node` instead.
