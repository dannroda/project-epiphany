---
name: removing-flags
description: "When removing a flag from data/flag_registry.tres, also grep debug/scenarios (signed save scenarios)"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 164c1d90-fbc8-437b-bcd4-3fb1eab41c01
  modified: 2026-10-14T13:56:48.334Z
---

Removing a flag from data/flag_registry.tres also means removing it from the debug save scenarios (debug/scenarios: travel, pre_temple, chullpa_la…). Those files are signed, so after editing them they have to be re-signed.

**Why:** in 11.166 I removed ow_shrine_switch without checking them. test_save_codec › test_scenarios_are_valid failed, and -fd had to fix it in main (d79b76ea).

**How to apply:** before committing a flag removal, run `grep -rn <flag> debug/scenarios` along with the usual src/tests/levels grep. Then run test_save_codec.
