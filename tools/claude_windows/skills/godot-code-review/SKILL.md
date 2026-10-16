---
name: "godot-code-review"
description: "Use when reviewing or refactoring Godot 4 GDScript/scenes for architecture smells, coupling, performance pitfalls and over-engineering, including jam-scope sanity checks."
---

# Godot 4 Code Review Checklist

Report findings ranked by impact. For each one: file and line, the smell, a concrete failure scenario, and the smallest fix. Point to `godot-architecture` or `godot-patterns` for the fix pattern. Don't suggest a pattern the project's scope doesn't justify.

## Coupling
- [ ] `get_parent()`, `owner.` or `get_node("../..")` used to call behavior → emit a signal instead.
- [ ] Long hardcoded paths (`$"../../UI/HUD/Label"`) → `@export` reference, `%UniqueName` inside the same scene, or a signal.
- [ ] Checking `body.name == "Player"` → class check (`body is Player`), a component, or a group constant.
- [ ] Unrelated branches reference each other → EventBus.
- [ ] Child script assumes the parent has a method (`get_parent().die()`).

## Responsibility
- [ ] Script over ~300 lines, or one that handles input, movement, combat, UI and audio together → split into components.
- [ ] `match`/if chain over an enum or flags longer than ~50 lines → State or Strategy.
- [ ] Boolean trap: `is_dashing`, `is_stunned`, `is_attacking` combined in conditionals → State.
- [ ] Autoload holding gameplay state (HP, inventory, score) or rules → Resource or domain object plus injection.
- [ ] Nodes used only to hold data → Resource or RefCounted.

## Safety and correctness
- [ ] Magic strings for groups, signals, input actions or animation names → constants (`const GROUP_ENEMY := &"enemy"`).
- [ ] `call_group` with a method name for critical logic → typed signals.
- [ ] Signal emitted in `_ready` that a sibling must catch (startup race) → push/pull from a shared Resource.
- [ ] Delayed or awaited code touching freed objects → `is_instance_valid()`.
- [ ] Unbounded arrays (histories, logs, pools).
- [ ] Shared `.tres` mutated per instance without `duplicate()`.
- [ ] External or JSON data used without type and range validation.
- [ ] Missing static types on vars, params and returns; `Variant` where a type is known.
- [ ] Physics bodies added or removed mid-callback without `call_deferred`.

## Performance
- [ ] `load()` or `instantiate()` of heavy scenes in hot paths → `preload` or threaded load.
- [ ] Per-frame `get_node()` or `find_child()` → cache in `@onready`.
- [ ] `_process` running on idle objects → `set_process(false)`, timers, or signals.
- [ ] Heavy per-instance nodes (FSM, many components) on mass objects (bullets, debris) → plain logic or a pool.
- [ ] Deep scene trees for simple entities.
- [ ] Audio players inside entities that get freed (sound cuts off) → pooled AudioService.

## Over-engineering (flag these too)
- [ ] A pattern with a single implementation and no planned second one.
- [ ] A state machine for something with two states.
- [ ] Generic components used by one entity.
- [ ] Dozens of tiny files with no folder structure.
- [ ] Factory or builder wrapping a one-off object.

## Jam mode (game jam / prototype)
When the project is a jam or prototype, review against shipping, not purity:
- Allowed: direct references inside a scene, booleans, one larger player script, hardcoded values that are clearly marked.
- Still required: Resources for values you'll tune, EventBus over spaghetti references across scenes, `preload` for spawned scenes, no crashes on freed objects.
- Suggest refactors only when they unblock the next feature or fix a bug.