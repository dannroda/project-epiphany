---
name: editor-check-separate-step
description: "check for Daniel's open editor in its OWN command, read the result, and only then merge in main; never chain pgrep + merge"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 288582ff-f0fb-4cb5-a598-45cacf4a334e
  modified: 2026-10-15T23:16:29.951Z
---

Before merging/importing in main, run the editor check (`pgrep -af "godot.*(-e|--editor)( |$)" | grep -v headless | grep -v pgrep`) as a separate Bash call and read its output. If it lists an editor, don't merge: tell Daniel and wait for him to close it.

**Why:** on 2026-10-15 I chained `pgrep ...; echo; git merge` twice in one command, and both times it merged under Daniel's open editor (beta1), touching scenes he might have had open.

**How to apply:** two steps, never one. Related: [[editor-version-wins]], [[worktrees-integration]].
