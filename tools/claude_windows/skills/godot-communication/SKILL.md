---
name: "godot-communication"
description: "Use for deep work on how Godot 4 systems talk: signal design, EventBus setup, event objects, autoload/service boundaries, dependency injection, init-order races, notifications."
---

# Godot 4 Communication & Global Systems

This skill is the detailed version of the communication part of `godot-patterns`. Use typed GDScript throughout.

## 1. The routing rule

Pick the channel by the relationship between sender and receiver:

| Relationship | Channel |
|---|---|
| Parent → own child | Direct call (`$Hitbox.enable()`, or an `@export` reference) |
| Child → parent / owner | Signal emitted by the child; the parent connects |
| Siblings in the same scene | The shared parent wires them together in `_ready` |
| Unrelated branches / different scenes | EventBus signal |
| Engine lifecycle (focus, close, pause, predelete) | `_notification(what)` |
| Many nodes, same simple operation (pause all, mute all) | Group with a constant name |

A node must work if its parent changes. If a script needs `get_parent()` to function, it is coupled. Fix that first.

## 2. Designing signals

- Name signals in the past tense or as a state change: `died`, `health_changed(current, max)`, `item_picked_up(item)`. They announce facts, never commands (`please_die` is wrong).
- Always type parameters: `signal health_changed(current: int, max_value: int)`.
- Connect in code with callables. Use `Callable.bind()` for extra context: `health.died.connect(_on_enemy_died.bind(enemy))`.
- Useful connect flags: `CONNECT_ONE_SHOT` for single-use events, `CONNECT_DEFERRED` to react at the end of the frame (safe for physics changes).
- Godot disconnects automatically when the target object is freed. Disconnect manually only when the receiver lives on but should stop listening, typically on autoload/EventBus signals from a pooled node. Do it in `_exit_tree()`.
- `await some_signal` pauses the function. If the emitter may be freed, the await never resumes, so guard any long awaits with a timeout (`get_tree().create_timer(t).timeout`) or validity checks.

## 3. EventBus

One autoload that only declares signals, with no logic and no state:

```gdscript
# core/event_bus.gd  -> autoload "EventBus"
extends Node

signal enemy_defeated(event: EnemyDefeatedEvent)
signal player_died
signal wave_started(index: int)
```

Rules:
- Emit from the system that knows the fact; listen wherever needed.
- Only for events that cross boundaries. Don't route parent/child traffic through the bus.
- If the bus grows past roughly 25 signals, namespace it.

### Namespacing (organizes the channels)
```gdscript
# event_bus.gd
extends Node
var combat := CombatEvents.new()
var ui := UIEvents.new()

# combat_events.gd
class_name CombatEvents extends RefCounted
signal enemy_defeated(event: EnemyDefeatedEvent)
signal player_hit(amount: int)
```
Usage: `EventBus.combat.enemy_defeated.connect(...)`.

### Event Objects (organize the payload)
When a signal carries several values or the data will grow, send one object:
```gdscript
class_name EnemyDefeatedEvent extends RefCounted
var enemy_id: StringName
var position: Vector2
var score: int
var killer: Node
```
Adding a field later breaks no receiver. In larger projects, use both: event objects sent over namespaced channels.

### Event Relay
Generic components emit generic signals (`HealthComponent.died`). The owner or spawner translates them into game events with context (`EventBus.combat.enemy_defeated.emit(event)`). That keeps components reusable and globals meaningful.

## 4. Autoloads

They are nodes that persist across scene changes, are globally reachable and exist once. Use them for **services**:
- EventBus, AudioService, SceneLoader/transitions, Settings, SaveService, Input remapping, networking.

Never use them for **gameplay state or rules**: player HP, inventory, score, wave logic. That becomes a script that does everything, hidden coupling, and memory that survives when it shouldn't.

Guidelines:
- Autoloads initialize in the order listed in Project Settings. An autoload may only depend on autoloads above it.
- Keep each autoload small, with one responsibility each.
- Expose methods, not mutable fields (`Settings.set_volume(bus, v)` instead of `Settings.volume = v` scattered everywhere).

### Alternatives
| Need | Use instead of an autoload |
|---|---|
| Stateless helpers / math | `static func` on a `class_name` script |
| Shared state between some objects | One `.tres` Resource referenced via `@export` |
| Per-level / per-match state | Domain object owned by a context and injected |
| Batch op on many nodes | Group with a constant name |

## 5. Dependency injection

Prefer passing dependencies over looking them up:

```gdscript
# Inspector injection
@export var stats: PlayerStats

# Setup injection (by the spawner/context)
func setup(state: LevelState, audio: AudioService) -> void:
    _state = state
    _audio = audio
```

- The creator (context, spawner, factory) calls `setup()` **before** `add_child()` so `_ready` already has everything.
- For autoload services, allow overrides for tests: `var audio: AudioService = AudioService` as the default, replaced by a mock in tests.

## 6. Init order and races

- `_ready` runs children before parents. Sibling order follows the tree.
- A signal emitted in `_ready` is lost if the listener hasn't connected yet.
- Fix with **push/pull**: keep the truth in a shared Resource or service. Listeners *pull* the current value in `_ready`, then subscribe for *pushes*.

```gdscript
class_name PlayerStats extends Resource
signal lives_changed(value: int)
@export var lives: int = 3:
    set(v):
        lives = v
        lives_changed.emit(lives)

# hud.gd
@export var stats: PlayerStats
func _ready() -> void:
    _show_lives(stats.lives)                  # pull
    stats.lives_changed.connect(_show_lives)  # push
```

- Otherwise use `call_deferred` or `await get_tree().process_frame` for one-off ordering. Don't use it as a habit.

## 7. Notifications

Override `_notification(what: int)` for engine events without dedicated callbacks:
- `NOTIFICATION_APPLICATION_FOCUS_OUT` / `_IN`: auto-pause, mute.
- `NOTIFICATION_WM_CLOSE_REQUEST`: save before quitting (set `get_tree().auto_accept_quit = false` first).
- `NOTIFICATION_PREDELETE`: last-chance cleanup (the object is still valid; avoid touching the tree).
- `NOTIFICATION_PAUSED` / `_UNPAUSED`.

## 8. Groups done safely

```gdscript
# core/groups.gd
class_name Groups
const ENEMY := &"enemy"
const DESTRUCTIBLE := &"destructible"
```
- Names are semantic (`Destructible`, never `Group1`), with one concept per group.
- Use them for tagging and batch operations (`get_tree().call_group(Groups.ENEMY, &"pause_ai")`) where a missing method doesn't matter.
- For anything that must not fail silently, use typed signals or an EventBus.

## 9. Testing communication

- Assert that signals fire: connect a lambda that records arguments, run the action, check the record.
- Mock services with RefCounted fakes exposing the same methods and signals.
- Test that systems still work when no one is listening (emitting with zero connections must be safe).