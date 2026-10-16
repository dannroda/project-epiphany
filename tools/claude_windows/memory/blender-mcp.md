---
name: blender-mcp
description: "User's Blender MCP is the official Blender Lab one (not ahujasid's mcp-for-blender); how it's wired"
metadata:
  node_type: memory
  type: reference
  originSessionId: 164c1d90-fbc8-437b-bcd4-3fb1eab41c01
  modified: 2026-10-09T21:32:56.716Z
---

The user chose the **official Blender Lab MCP** (2026-10-09): add-on `mcp` from the lab.blender.org extensions repo (Blender 5.2, port 9876), server in user config as `uvx --from "git+https://projects.blender.org/lab/blender_mcp.git#subdirectory=mcp" blender-mcp`. Not the PyPI `blender-mcp`/`mcp-for-blender` (ahujasid): same port, different protocol, handshake fails.

Tools: execute_blender_code, screenshots of window/area, render_viewport_to_path, API/manual doc search, *_for_cli variants that open a .blend in background Blender. No asset libraries or AI generation.

The server must be started inside Blender (add-on preferences: Start, or auto-start). Headless `blender -b -P script.py` works regardless and is how tools/blender/*.py run. See [[mvp-direction]].
