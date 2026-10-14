@tool
class_name AmbienteSala
extends Node
## Hijo de una Room: pisa en esa sala solo los valores tildados del WorldEnvironment del nivel (su Environment y la
## viñeta del TonoLA). Lo que no se tilda sigue al nodo del nivel. La cámara lo aplica al entrar a la sala y lo devuelve
## al salir; con el juego abierto, lo que se cambia acá o en el nivel se ve en el momento.

const TONE := preload("res://src/world/look/tono_la.gd")
const TONE_PREFIX := "tono_"
const TONE_PROPERTIES := ["exposure", "vignette", "frame", "frame_softness", "frame_slant", "frame_sides", "frame_top", "frame_bottom"]

## Lo tildado: nombre de la propiedad del Environment (o tono_<propiedad> del TonoLA) → valor.
@export_storage var valores: Dictionary = {}

static var _names: Dictionary = {}

var _world: WorldEnvironment
var _saved: Dictionary = {}


func _get_property_list() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for property in ClassDB.class_get_property_list("Environment", true):
		var entry: Dictionary = property.duplicate()
		if entry.usage & PROPERTY_USAGE_EDITOR:
			entry.usage = PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_CHECKABLE | (PROPERTY_USAGE_CHECKED if valores.has(entry.name) else 0)
		elif not entry.usage & (PROPERTY_USAGE_GROUP | PROPERTY_USAGE_SUBGROUP):
			continue
		list.append(entry)
	list.append({"name": "Viñeta", "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP, "hint_string": TONE_PREFIX})
	for property in TONE_PROPERTIES:
		var name: String = TONE_PREFIX + property
		list.append({"name": name, "type": TYPE_FLOAT, "usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_CHECKABLE | (PROPERTY_USAGE_CHECKED if valores.has(name) else 0)})
	return list


func _get(property: StringName) -> Variant:
	if not _overridable(property):
		return null
	if valores.has(String(property)):
		return valores[String(property)]
	return _level_value(String(property))


func _set(property: StringName, value: Variant) -> bool:
	if not _overridable(property):
		return false
	var key := String(property)
	if value == null:
		valores.erase(key)
		_put_back(key)
	else:
		if not valores.has(key) and value == type_convert(null, typeof(value)):
			var current: Variant = _level_value(key)
			value = current if current != null else value
		valores[key] = value
		_put(key)
	notify_property_list_changed()
	return true


func _property_can_revert(property: StringName) -> bool:
	return valores.has(String(property))


func _property_get_revert(property: StringName) -> Variant:
	return _level_value(String(property))


## Pone lo tildado en el WorldEnvironment del nivel, guardando lo que había.
func apply(world: WorldEnvironment) -> void:
	restore()
	_world = world
	for key: String in valores:
		_put(key)


## Devuelve al WorldEnvironment lo que había antes de entrar.
func restore() -> void:
	for key: String in _saved.keys():
		_put_back(key)
	_world = null


func _exit_tree() -> void:
	restore()


func _put(key: String) -> void:
	var target := _target(key)
	if target == null:
		return
	var property := key.trim_prefix(TONE_PREFIX)
	if not _saved.has(key):
		_saved[key] = target.get(property)
	target.set(property, valores[key])


func _put_back(key: String) -> void:
	if not _saved.has(key):
		return
	var target := _target(key)
	if target:
		target.set(key.trim_prefix(TONE_PREFIX), _saved[key])
	_saved.erase(key)


func _target(key: String) -> Object:
	if _world == null:
		return null
	if not key.begins_with(TONE_PREFIX):
		return _world.environment
	for effect in _world.compositor.compositor_effects if _world.compositor else []:
		if effect.get_script() == TONE:
			return effect
	return null


func _overridable(property: StringName) -> bool:
	var key := String(property)
	if key.begins_with(TONE_PREFIX):
		return key.trim_prefix(TONE_PREFIX) in TONE_PROPERTIES
	if _names.is_empty():
		for entry in ClassDB.class_get_property_list("Environment", true):
			if entry.usage & PROPERTY_USAGE_EDITOR:
				_names[entry.name] = true
	return _names.has(key)


func _level_value(key: String) -> Variant:
	if _saved.has(key):
		return _saved[key]
	var world := _level_world_environment()
	if world == null:
		return null
	if key.begins_with(TONE_PREFIX):
		for effect in world.compositor.compositor_effects if world.compositor else []:
			if effect.get_script() == TONE:
				return effect.get(key.trim_prefix(TONE_PREFIX))
		return null
	return world.environment.get(key) if world.environment else null


func _level_world_environment() -> WorldEnvironment:
	var root: Node = owner if owner else get_tree().current_scene if is_inside_tree() else null
	if root == null:
		return null
	var found := root.find_children("*", "WorldEnvironment", true, false)
	return found[0] as WorldEnvironment if not found.is_empty() else null
