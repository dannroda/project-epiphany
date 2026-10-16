---
name: "godot-architecture"
description: "Use when starting or structuring a Godot 4 project or system: where code/data should live, scenes vs scripts vs Resources, folders, naming, layers, data-driven content, saves and mods."
---

# Godot 4 Architecture

Target: Godot 4.x (4.7+), GDScript with static typing everywhere (`var hp: int`, `-> void`).
Guiding rule: clarity over minimalism. Every scene, node and script exists for one reason.

## 1. Pick the right container

Ask "what is this thing?" before creating a node.

| It is... | Use | Why |
|---|---|---|
| Something that renders, collides, plays audio, receives input, or needs `_process` | **Node / Scene** | Lives in the SceneTree |
| Data or configuration (stats, items, abilities, wave tables, settings) | **Resource** (`class_name X extends Resource`, `.tres`) | Inspector-editable, serializable, shareable, no tree cost |
| Pure logic (inventory model, damage calc, FSM model, rules) | **RefCounted** | Auto-freed, testable without a scene |
| Manually-managed low-level object | **Object** | Rare; must `free()` yourself |
| Stateless helpers (math, RNG, formatting) | **static func** on a `class_name` script | No instance needed |

Anti-pattern: an `Inventory` node with `Item` child nodes. Use an `Inventory` RefCounted/Resource holding `Array[ItemData]`; a UI scene only *displays* it.

## 2. Scenes vs scripts

- Scene = declarative (what exists, layout, visuals). Script = imperative (behavior).
- Shared behavior: prefer **composition** (child component nodes or Resource-based components) over deep script inheritance. Keep inheritance ≤ 2 levels.
- **Inherited Scenes**: for visual/structural variants of the same thing (enemy skins, variants).
- `@tool` scripts: editor previews, configuration warnings (`_get_configuration_warnings()`), validation.
- Instantiation is synchronous. Never `load(...).instantiate()` in hot gameplay code. Use `const X := preload(...)` or `ResourceLoader.load_threaded_request()` behind a loading screen.

## 3. Scene hierarchy rules

1. Keep scenes shallow; extract subtrees into their own scenes.
2. Instance for reuse; every scene should run standalone (F6) as far as possible.
3. Loose coupling: a scene never reaches outside itself with `get_node("../../X")`. It exposes `@export` slots and signals instead.
4. Free what you don't need (`queue_free()`), spawn on demand.

## 4. Project layout (convention: feature-based)

Group by feature, not file type, so a feature can be copied to another project as one folder:

```
res://
  core/            # autoloads, services, event bus, shared base classes
  features/
    player/        # player.tscn, player.gd, player_stats.tres, sprites
    enemies/grunt/
    ui/hud/
  data/            # shared .tres databases, JSON
  shared/          # generic components (health_component.gd, hitbox_component.gd)
  addons/
```

Naming:
- Files and folders: `snake_case` (`enemy_controller.gd`, `main_menu.tscn`).
- `class_name` matches the file in PascalCase (`enemy_controller.gd` → `EnemyController`). Scene root node in PascalCase.
- Node names with clear role (`HealthLabel`, `ShootTimer`) so `$HealthLabel` and `health` never collide.
- Groups and other string keys are constants, never literals (see godot-patterns).

## 5. Data-driven design

Separate **hard architecture** (rules, code) from **soft architecture** (content, numbers).

- Every tunable number lives in a Resource, not in a script constant.
- Nest Resources for mix-and-match (`EnemyData` has `movement: MovementData`, `weapon: WeaponStrategy`).
- Shared `.tres` instances are shared state. Call `duplicate(true)` when an entity needs its own mutable copy (prototype pattern).

```gdscript
class_name EnemyData extends Resource
@export var max_hp: int = 10
@export var speed: float = 120.0
@export var weapon: WeaponStrategy
```

### External data (JSON) is zero-trust
- Check the file exists, the parse succeeds (`JSON.new().parse()` returns `OK`), the root is the expected type, each key exists and has the right `typeof()`, and values are clamped to sane ranges.
- On any failure: `push_warning()`, skip that entry, keep the game running. Never crash on bad data.

### Mods
- Read from `user://mods/`, not `res://` (the exported .pck is sealed).
- Load images with `Image.load_from_file()` → `ImageTexture.create_from_image()`, after validating the path and the result.
- Mods only supply data. Never execute mod-supplied scripts unless that is an explicit, sandboxed design choice.

## 6. Macro-architecture (mid/large projects)

- **Presentation layer**: nodes, animation, UI. Reads state and emits user intent.
- **Domain layer**: RefCounted state and rules (`LevelState`, `Inventory`). No node references, no `get_tree()`.
- **Contexts**: `RootContext` (main scene, owns global services) → `MainMenuContext` / `GameplayContext`. A context builds its children and **injects** dependencies (`controller.setup(state)`, `hud.bind(state)`). Children never look dependencies up globally.
- **Persistence**: save the domain data objects (to Dictionary/JSON or Resource), never node paths. `GameplayContext` hands its state to a `SaveService`.

## 7. Scale the architecture to the project

- **Jam or prototype (≤ 2 weeks)**: Resources for tunables, signals, one EventBus, one AudioService. Skip contexts, layers and commands unless the core mechanic needs them.
- **Long-lived game**: everything above, plus tests for the domain layer.
- When in doubt: YAGNI. Refactor when the pain shows up (see godot-code-review).