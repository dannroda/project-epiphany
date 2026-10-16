---
name: gdscript-reserved-method-names
description: "Don't name GDScript helpers _set/_get/_init etc.; they override Object virtuals and fail to parse"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 6d9b9e44-5f38-4fea-9355-1ae9026939fc
  modified: 2026-10-08T06:24:25.135Z
---

Never name a GDScript method `_set`, `_get`, `_get_property_list`, `_notification`, `_to_string` or other Object virtual names. `_set(a, b)` fails with "The function signature doesn't match the parent". I hit this three times on Epiphany (flags_tab, the BT generator, InputDevice) on 2026-10-08.

**Why:** It costs a failed run every time and the error only shows when the script loads.

**How to apply:** Use descriptive names (`_set_flag`, `_set_var`, `_switch_to`).
