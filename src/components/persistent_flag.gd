@tool
class_name PersistentFlag
extends Node
## Une un objeto del mundo con un flag de GameState: avisa el valor al entrar a la escena,
## al cambiar y al cargar una partida, y lo escribe cuando el objeto cambia.

signal changed(value: Variant)

const REGISTRY_PATH := "res://data/flag_registry.tres"
const OVERWORLD_PREFIX := "ow"

## Puede llegar después de `_ready` (lo copia el objeto dueño del flag en su `_ready`).
@export var flag: StringName:
	set(value):
		flag = value
		update_configuration_warnings()
		if is_node_ready():
			_watch()

var _watching := false

var value: Variant:
	get:
		return GameState.get_flag(flag) if flag != &"" else null
	set(new_value):
		if flag != &"":
			GameState.set_flag(flag, new_value)


func _ready() -> void:
	_watch()


func _watch() -> void:
	if Engine.is_editor_hint() or flag == &"" or _watching:
		return
	_watching = true
	GameState.flag_changed.connect(func(id: StringName, new_value: Variant) -> void:
		if id == flag:
			changed.emit(new_value))
	GameState.loaded.connect(func() -> void: changed.emit(value))
	(func() -> void: changed.emit(value)).call_deferred()


func _get_configuration_warnings() -> PackedStringArray:
	if get_parent() and &"flag" in get_parent():
		return PackedStringArray()
	return warnings_for(flag, false, self)


## También la usan los objetos que exportan su propio `flag` (cofres, tablillas). En una mazmorra el flag empieza con
## el id de su Dungeon; afuera puede leer los de cualquier lado (el overworld mira si se venció un jefe).
static func warnings_for(id: StringName, optional: bool, node: Node = null) -> PackedStringArray:
	if id == &"":
		return PackedStringArray() if optional else PackedStringArray(["Falta el flag."])
	var warnings := PackedStringArray()
	var registry := load(REGISTRY_PATH) as FlagRegistry
	if registry and not registry.has(id):
		warnings.append("El flag \"%s\" no está en flag_registry.tres." % id)
	var prefix := prefix_for(node) if node else OVERWORLD_PREFIX
	if prefix != OVERWORLD_PREFIX and not String(id).begins_with(prefix + "_"):
		warnings.append("El flag \"%s\" no sigue la convención: en esta escena empieza con %s_." % [id, prefix])
	return warnings


## El id del Dungeon de la escena de `node` (lo que va antes del primer _ de sus flags), u `ow` si no tiene.
static func prefix_for(node: Node) -> String:
	var root := node.owner if node.owner else node
	if node.is_inside_tree() and Engine.is_editor_hint() and node.get_tree().edited_scene_root:
		root = node.get_tree().edited_scene_root
	for dungeon in root.find_children("*", "Dungeon", true, false):
		return String(dungeon.get(&"id"))
	return OVERWORLD_PREFIX
