---
name: limboai-patched-build
description: "addons/limboai: editor libs are the user's patched build for Godot 4.8 (editor UI only); export template_release libs are the official LimboAI 1.8.1 gdextension, tested OK"
metadata:
  node_type: memory
  type: project
  originSessionId: 0cf56780-b66c-401e-b2e9-59605e0757d6
  modified: 2026-10-11T02:59:29.425Z
---

`addons/limboai/bin/` mixes two builds under the same (official, unchanged) `limboai.gdextension`:
- `*.editor.*` (linux .so, windows .dll): the user's own patched build, because Godot 4.8 changed the main screen plugin system. The patch only touches editor main-screen UI. Debug exports also load these.
- `*.template_release.*` (linux, windows, macos framework, web wasm32 nothreads): copied unchanged from the official `limboai+v1.8.1.gdextension-4.6.zip` release. Decided 2026-10-10; release export of Linux + Windows and running the Linux build on the temple (player LimboHSM, enemy BTs) showed no errors.

The project is locked to Godot 4.8: it uses the new AnimationTree ObserverNodes (e.g. `AnimationNodeObserverOneShot`), so going back to 4.7 is not an option.

**Why:** the user's patch doesn't matter at runtime, so there's no need to compile templates themselves.
**How to apply:** don't flag export/LimboAI as a blocker, don't suggest downgrading to 4.7, never replace the editor binaries with upstream ones. If more platforms are needed (android, arm64), take their template_release from the same official 1.8.1 zip. Release templates refuse a scene path on the CLI; to test a level in a release build drop a temporary `override.cfg` with `run/main_scene` next to the binary.
