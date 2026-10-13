@tool
class_name PersistentFlag
extends Node
## Une un objeto del mundo con un flag de GameState: avisa el valor al entrar a la escena,
## al cambiar y al cargar una partida, y lo escribe cuando el objeto cambia.

signal changed(value: Variant)

const REGISTRY_PATH := "res://data/flag_registry.tres"
const PREFIXES: PackedStringArray = ["ow_", "d0_", "d1_", "ch_", "qv_", "te_"]

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
	return warnings_for(flag, false)


## También la usan los objetos que exportan su propio `flag` (cofres, tablillas).
static func warnings_for(id: StringName, optional: bool) -> PackedStringArray:
	if id == &"":
		return PackedStringArray() if optional else PackedStringArray(["Falta el flag."])
	var warnings := PackedStringArray()
	var registry := load(REGISTRY_PATH) as FlagRegistry
	if registry and not registry.has(id):
		warnings.append("El flag \"%s\" no está en flag_registry.tres." % id)
	if not Array(PREFIXES).any(func(prefix: String) -> bool: return String(id).begins_with(prefix)):
		warnings.append("El flag \"%s\" no sigue la convención: ow_* (overworld) o el prefijo de la mazmorra (d1_ el templo viejo, te_ el templo, ch_ la Chullpa, qv_ la Queñoa)." % id)
	return warnings
