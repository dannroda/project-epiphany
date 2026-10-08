@tool
class_name PersistentFlag
extends Node
## Une un objeto del mundo con un flag de GameState: avisa el valor al entrar a la escena,
## al cambiar y al cargar una partida, y lo escribe cuando el objeto cambia.

signal changed(value: Variant)

const REGISTRY_PATH := "res://data/flag_registry.tres"
const PREFIXES: PackedStringArray = ["ow_", "d1_", "d2_", "d3_"]

@export var flag: StringName:
	set(value):
		flag = value
		update_configuration_warnings()

var value: Variant:
	get:
		return GameState.get_flag(flag) if flag != &"" else null
	set(new_value):
		if flag != &"":
			GameState.set_flag(flag, new_value)


func _ready() -> void:
	if Engine.is_editor_hint() or flag == &"":
		return
	GameState.flag_changed.connect(func(id: StringName, new_value: Variant) -> void:
		if id == flag:
			changed.emit(new_value))
	GameState.loaded.connect(func() -> void: changed.emit(value))
	changed.emit.call_deferred(value)


func _get_configuration_warnings() -> PackedStringArray:
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
		warnings.append("El flag \"%s\" no sigue la convención: ow_* (overworld) o dN_* (mazmorra N)." % id)
	return warnings
