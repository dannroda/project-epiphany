@tool
class_name AmbienteSala
extends Node
## Hijo de una Room: pisa en esa sala solo los valores tildados del WorldEnvironment del nivel (su Environment y la
## viñeta del TonoLA). Lo que no se tilda sigue al nodo del nivel. La cámara lo aplica al entrar a la sala.

const TONE := preload("res://src/world/look/tono_la.gd")
const TONE_PREFIX := "tono_"
const TONE_PROPERTIES := ["exposure", "vignette", "frame", "frame_softness", "frame_slant"]

## Lo tildado: nombre de la propiedad del Environment (o tono_<propiedad> del TonoLA) → valor.
@export_storage var valores: Dictionary = {}

static var _names: Dictionary = {}

var _environment: Environment
var _compositor: Compositor


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
	elif valores.has(key) or not Engine.is_editor_hint():
		valores[key] = value
	else:
		var current: Variant = _level_value(key)
		valores[key] = current if current != null else value
	_environment = null
	_compositor = null
	notify_property_list_changed()
	return true


func _property_can_revert(property: StringName) -> bool:
	return valores.has(String(property))


func _property_get_revert(property: StringName) -> Variant:
	return _level_value(String(property))


## El Environment del nivel con lo tildado encima.
func environment_over(level: Environment) -> Environment:
	if _environment == null and level:
		_environment = level.duplicate() as Environment
		for key: String in valores:
			if not key.begins_with(TONE_PREFIX):
				_environment.set(key, valores[key])
	return _environment


## El Compositor del nivel con la viñeta tildada encima; sin nada tildado de la viñeta, el del nivel.
func compositor_over(level: Compositor) -> Compositor:
	if level == null or not valores.keys().any(func(key: String) -> bool: return key.begins_with(TONE_PREFIX)):
		return level
	if _compositor == null:
		_compositor = level.duplicate() as Compositor
		var effects: Array[CompositorEffect] = []
		for effect in level.compositor_effects:
			var copy := effect.duplicate() as CompositorEffect
			if copy.get_script() == TONE:
				for key: String in valores:
					if key.begins_with(TONE_PREFIX):
						copy.set(key.trim_prefix(TONE_PREFIX), valores[key])
			effects.append(copy)
		_compositor.compositor_effects = effects
	return _compositor


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
