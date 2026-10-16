---
name: "godot-data-driven"
description: "Use for deep work on data-driven Godot 4 content: custom Resource design, databases/registries, JSON or CSV import with validation, save files, mod loading, and designer-facing editor tooling."
---

# Godot 4 Data-Driven Design

This skill is the detailed version of the data section of `godot-architecture`.
Core idea: code defines the **rules** (hard architecture); data defines the **content** (soft architecture). New content should take a new file, not new code.

## 1. Designing custom Resources

```gdscript
class_name WeaponData extends Resource

@export var id: StringName
@export var display_name: String
@export_group("Stats")
@export_range(0.05, 5.0, 0.05, "suffix:s") var cooldown: float = 0.25
@export_range(1, 999) var damage: int = 1
@export_group("Visuals")
@export var icon: Texture2D
@export var projectile_scene: PackedScene
```

- Give every Resource that gets referenced by ID a stable `id: StringName`.
- Use `@export_range`, `@export_enum`, `@export_group`, `@export_category` and `@export_flags` so designers can't enter nonsense.
- Use typed containers: `@export var drops: Array[ItemData]`.
- Put behavior in Resources only when it is a **strategy** (a `fire()` or `move()` method that subclasses override). Plain data Resources have no logic beyond small computed getters.
- Validate in the editor: a `@tool` Resource can implement `_validate_property()` to hide or show fields. Scenes that use it can report problems through `_get_configuration_warnings()`.

### Composition through nesting
`EnemyData` → `movement: MovementData`, `weapon: WeaponData`, `loot: LootTable`. Mix and match sub-resources in the Inspector to create variants without code.

### Shared vs per-instance data
- A `.tres` loaded twice is the **same object**. Mutating it changes every user.
- Template data (base stats) stays read-only at runtime.
- Per-instance mutable state: `duplicate(true)` at spawn, or `resource_local_to_scene = true` for sub-resources embedded in scenes. For nested Resources inside arrays/dictionaries, use `duplicate_deep()` (Godot 4.5+) and verify the behavior on your engine version.
- Better yet: copy the needed values into a runtime state object (RefCounted) and keep templates untouched.

## 2. Databases and registries

One place to find content by ID:

```gdscript
class_name ContentDB extends Resource
@export var weapons: Array[WeaponData]
var _by_id: Dictionary = {}

func build_index() -> void:
    _by_id.clear()
    for w in weapons:
        assert(not _by_id.has(w.id), "Duplicate id: %s" % w.id)
        _by_id[w.id] = w

func get_weapon(id: StringName) -> WeaponData:
    return _by_id.get(id)
```

- Fill it by hand in the Inspector (small projects), or scan a folder.
- Folder scanning: in exported builds, `res://` contains `.remap` and `.import` entries. Use `ResourceLoader.list_directory()` (Godot 4.4+) or strip the `.remap` suffix before loading. Test this in an export, not only in the editor.
- Load the DB once (a service or context) and inject it. Don't call `load()` per lookup.

## 3. External text data (JSON / CSV)

Use it for content edited outside Godot (writers, spreadsheets, translators, modders).
- JSON: nested content (enemies, dialogue, waves).
- CSV: balance tables and localization (Godot imports CSV translations natively).

### Zero-trust loading
Treat every external file as hostile or broken. Fail per entry, never per game.

```gdscript
static func load_json(path: String) -> Variant:
    if not FileAccess.file_exists(path):
        push_warning("Missing data file: %s" % path)
        return null
    var json := JSON.new()
    var err := json.parse(FileAccess.get_file_as_string(path))
    if err != OK:
        push_warning("%s:%d %s" % [path, json.get_error_line(), json.get_error_message()])
        return null
    return json.data

static func read_int(d: Dictionary, key: String, fallback: int, lo: int, hi: int) -> int:
    var v: Variant = d.get(key, fallback)
    if typeof(v) not in [TYPE_INT, TYPE_FLOAT]:
        push_warning("Bad type for '%s'" % key)
        return fallback
    return clampi(int(v), lo, hi)
```

Checklist per file:
- [ ] The file exists and parses; the root type is what you expect (`Dictionary` / `Array`).
- [ ] A `"version": n` field is present. Migrate old versions, reject unknown future ones.
- [ ] Each required key exists with the right `typeof()`. JSON numbers arrive as float.
- [ ] Numbers are clamped; strings are length-limited; IDs are unique and references resolve.
- [ ] Asset paths stay inside allowed roots (no `..`, no absolute paths).
- [ ] Errors are collected and shown in one report (log or debug overlay).

Convert validated data into typed Resources or RefCounted objects right away. Gameplay code never touches raw Dictionaries.

## 4. Save files

- Save **domain data**, not nodes or node paths. Each state object has `to_dict()` / `static from_dict()`.
- Write to `user://`. Write to a temporary file, then rename over the old one, so a crash mid-save doesn't corrupt it. Keep one backup.
- Include `version` in every save and migrate on load.
- Formats: JSON for readability and modding; `FileAccess.store_var()` for compact binary (never with `full_objects = true` on untrusted data); `ConfigFile` for settings.
- **Security:** don't load `.tres`/`.res` files from `user://` or from downloads. Resources can embed scripts that run on load. Use JSON or ConfigFile for anything a player could edit or share.

## 5. Mod pipeline

1. On startup, list `user://mods/*/` (each mod is a folder with a `mod.json` manifest: id, name, version, game_version).
2. Validate the manifest; skip incompatible mods and log why.
3. Load data JSON through the same zero-trust loaders as the base content.
4. Load images with `Image.load_from_file()` → `ImageTexture.create_from_image()`. Validate the size and the result; fall back to a placeholder texture.
5. Load audio from user files with the runtime loaders (`AudioStreamOggVorbis.load_from_file()`, `AudioStreamWAV.load_from_file()` on 4.3+/4.4+; check your version).
6. Register content in the ContentDB with namespaced IDs (`modid:laser_mk2`). Define the override policy explicitly: a mod can replace base content or only add to it.
7. Data only. Running mod scripts is a separate, explicit decision with a security review.

## 6. Designer workflow

- Tunables live in `.tres` files, never in `const` inside scripts.
- Debug tooling: a `@tool` scene preview that draws ranges or spawn patterns from the data; a debug overlay to hot-swap Resources at runtime.
- Hot reload during play: re-read JSON on a debug key and re-run validation.
- Keep balance in one place. If a number appears in two files, one of them is wrong.

## 7. When not to go data-driven

- A one-off mechanic or boss whose logic is the content: write code.
- Jam scope: Resources for tunables, yes. JSON, mods and registries only if the theme needs them.
- Don't build a generic system for content that has three instances.