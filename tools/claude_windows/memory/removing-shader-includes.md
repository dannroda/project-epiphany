---
name: removing-shader-includes
description: "Before deleting a .gdshaderinc, grep every .gdshader for all its functions/uniforms; headless tests don't compile shaders"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 164c1d90-fbc8-437b-bcd4-3fb1eab41c01
  modified: 2026-10-16T05:22:15.203Z
---

When removing a shader include (.gdshaderinc), grep every .gdshader for each function and global it defines (not just the `#include` line and the obvious call), and check the shaders compile with a windowed run.

**Why:** removing cloud_shadows.gdshaderinc (2026-10-15, abd73bf4) left abyss_mist.gdshader calling cloud_noise. The mist failed to compile and wasn't drawn, and nobody noticed because headless tests don't compile shaders. -67 caught it in the shader baker export (fixed in f3335aef).

**How to apply:** `grep -rn 'func1\|func2\|global' --include='*.gdshader*' .` for every symbol in the include, then a windowed capture (screen 1, no_focus, see [[windowed-godot-second-monitor]]) of a scene using each touched shader. Related: [[removing-flags]].
