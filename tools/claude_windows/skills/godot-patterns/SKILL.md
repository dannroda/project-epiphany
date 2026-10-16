---
name: "godot-patterns"
description: "Use when implementing gameplay systems in Godot 4: signals, autoloads, event bus, state machines, strategies, components, spawners/factories, builders, commands/undo, services."
---

# Godot 4 Patterns

Use typed GDScript. Each pattern below has a "don't" line. Read it before reaching for the pattern.

## 1. Communication: Call Down, Signal Up, Event Out

- **Down** (parent → child): direct calls are fine (`$Hitbox.enable()`).
- **Up** (child → parent): signals only. A child never calls `get_parent()`. It announces *what happened*, not what should happen.
- **Out** (unrelated branches): a global EventBus autoload that only declares signals.

```gdscript
# core/event_bus.gd  (autoload "EventBus")
extends Node
signal enemy_defeated(event: EnemyDefeatedEvent)
signal player_lives_changed(lives: int)
```

- Connect in code with callables: `EventBus.enemy_defeated.connect(_on_enemy_defeated)`.
- **Event Objects**: when a signal's data grows or changes often, send one RefCounted payload class instead of many arguments. Adding a field then doesn't break any receiver.
- **Namespacing**: when the bus gets big, split it (`EventBus.audio`, `EventBus.combat` as sub-objects) or use several buses.
- **Startup race**: a signal emitted before the listener connects is lost (`_ready` runs children-first). Fix with push/pull: the listener reads the current value from a shared Resource in `_ready`, then subscribes for changes.
- **Observable Resource**: a setter that emits `changed` (or a custom signal) makes data reactive.

```gdscript
class_name PlayerStats extends Resource
signal lives_changed(value: int)
@export var lives: int = 3:
    set(v):
        lives = v
        lives_changed.emit(lives)
```

- Engine lifecycle events (focus lost, close request, pause, predelete) come in through `_notification(what)`, not custom signals.
- Don't: use `call_group("x", "method")` for important broadcasts. It is untyped and fails silently. Groups are fine for tagging and batch operations, with names kept in constants.

## 2. Autoloads: services, not state

Good autoloads: EventBus, AudioService, SceneLoader/transitions, Settings/config, SaveService, network.
Bad: `Global.gd` holding player HP, inventory, score and game rules (a script that does everything).

- Gameplay state goes in Resources or domain objects injected by a context.
- Make services injectable for tests: `func setup(audio: AudioService = AudioService)` or a setter.
- **AudioService**: stateless API (`play_sfx(stream, pos)`) backed by a pool of reusable `AudioStreamPlayer(2D)` nodes, so sounds survive when the emitting entity is freed. Pool size capped; reuse the oldest player when it is exhausted.

## 3. State vs Strategy

| Situation | Use |
|---|---|
| Modes or phases of one entity (Idle/Chase/Attack, Grounded/Air) | **State** |
| Interchangeable variants of a tool or behavior (Laser/Spread/Missile, movement styles) | **Strategy** (Resource) |
| `match` or if/elif over an enum longer than ~50 lines, or several booleans that combine | Refactor into one of the above |
| Simple on/off | Plain `bool` |

**State (node FSM)**: `StateMachine` node with `State` children. Each state has `enter()`, `exit()`, `physics_update(delta)` and requests transitions by emitting `transition_requested(next_state)`. The machine performs the switch. Inside `physics_update`: guard clauses that decide a transition come first, then movement.

**Strategy (Resource)**:
```gdscript
class_name WeaponStrategy extends Resource
@export var cooldown: float = 0.2
func fire(spawner: Node2D, origin: Transform2D) -> void:
    pass  # override in subclasses
```
The owner holds `@export var weapon: WeaponStrategy` and calls `weapon.fire(...)`. Swap at runtime by assigning a new Resource.

Don't: give 5,000 particles an FSM node each, or build a state machine for a door.

## 4. Components (composition)

- Small single-purpose nodes: `HealthComponent`, `HitboxComponent`, `HurtboxComponent`, `MovementComponent`, `ShooterComponent`.
- Entity root = thin "motherboard" that wires its components with `@export` references.
- Components talk through signals (chain: Hurtbox → `hit(dmg)` → Health → `died`). They never assume their parent's type.
- **Event Relay**: the spawner or owner translates generic signals into game events (`health.died` → `EventBus.enemy_defeated.emit(...)`), so components stay generic.
- Use components for behavior shared by several entity types. Don't build generic components for one-off objects.

## 5. Creation: Factory vs Builder

| | Factory | Builder |
|---|---|---|
| Goal | Many ready-made, mostly identical instances | One highly configured object |
| API | `spawn(scene, pos) -> Node` | `.with_title(..).with_size(..).build()` (each method `return self`) |
| Use for | enemies, bullets, pickups, VFX | dynamic UI, procedural rooms/levels |
| Don't | build a factory for a single boss | use a builder for 1–2 properties |

Factory/Spawner: hides `instantiate()`, parenting, setup injection, and deferred adds during physics (`add_child.call_deferred(...)`). Combine it with small placement components (radial/area randomizers) for procedural spawning. Pool bullets if profiling shows churn.

## 6. Command

Encapsulate an action as a RefCounted object: `execute(actor)` and optionally `undo(actor)`.
- Input maps to commands, so remapping, AI driving the same actor, buffering, replays and networking get easier.
- Queue rules: check `is_instance_valid(actor)` before executing; cap the history (`MAX_HISTORY`) and drop the oldest; make every awaited command finish (timeout or exit condition) so the queue can't jam.
- Undo/redo: two stacks. A command caches what it needs to reverse (for example the start position) during `execute`. A new command clears the redo stack.
- Action games may run commands in parallel or immediately; turn-based and puzzle games queue them.

## 7. Testing

Domain objects, commands and services are testable without scenes: build them with mock dependencies (a fake RefCounted with the same methods) and assert results. Test failure paths too: invalid actor, bad data, empty pool.