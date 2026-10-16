---
name: editor-churn-discard
description: "what the Godot editor saves when Daniel opens it wins over the sessions' versions; never discard or revert it, and the editor's navmesh is the good one"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 288582ff-f0fb-4cb5-a598-45cacf4a334e
  modified: 2026-10-14T21:38:22.568Z
---

Daniel (2026-10-14, replaces his earlier "you can discard editor churn"): the changes the editor makes when he opens it take priority over the sessions' generated files. He commits them himself (e.g. 97627968 "Tweaks": levels, kits, door .res, plus his own tweaks) and they are correct. Don't discard them, don't restore files to a pre-editor commit, don't strip "churn" out of his commits. The sessions' tools also generate the NavigationMesh wrong; the one the editor bakes is the good one.

**Why:** I twice treated his editor saves as churn (dropped overrides, navmesh shift) and tried to restore the generated versions; he stopped me: "no rompas mis tweaks".

**How to apply:** when main has uncommitted editor saves, ask him or commit them as his; never `git checkout --` them. Peers' refreshes (la_walls) must rebase onto his commits and not reintroduce their own navmesh/overrides over his. The tscn semantic diff is only for telling him what changed, not for deciding what to throw away. Related: [[editor-resave-drops-overrides]], [[refresh-levels-after-rebase]], [[godot-logs-for-provenance]].
