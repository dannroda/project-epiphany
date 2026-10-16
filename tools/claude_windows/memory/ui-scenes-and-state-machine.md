---
name: ui-scenes-and-state-machine
description: "Build UI as .tscn scenes, never by code; screens go through the UI state machine (MenuStack) so only the top screen gets input"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 6d9b9e44-5f38-4fea-9355-1ae9026939fc
  modified: 2026-10-09T05:27:04.803Z
---

Never build UI by code (no Label.new()/VBoxContainer.new() trees in _ready): every screen, panel, row and dialog is a `.tscn` the user can open and edit in the editor. Scripts only fill data and react. Repeated items (slots, list rows, hints) are their own small scenes, instantiated per item. Styling goes in `src/ui/theme.tres` variations, not `add_theme_*_override` in code.

Every screen (title sub-screens, options, file select, dialogs, game over, pause) goes through the UI state machine (`MenuStack`, a pushdown automaton of `UiScreen` states): only the top screen receives input and focus; covered screens are disabled (and hidden when the new one is full-screen).

**Why:** 2026-10-09 the user found that with Options open from the title, the debug "Cargar escenario" button behind it was still clickable, because I had layered code-built overlays and disabled only part of the title. They asked explicitly: "NO GENERES UI POR CODIGO, USA ESCENAS. Y debería haber una máquina de estado para manejar mejor la ui y los inputs".

**How to apply:** for any new screen, create the `.tscn` first (following [[ui-mockups-artifact]]), extend `UiScreen`, and open it with `MenuStack.push()`. Related: [[minimal-code-comments]].
