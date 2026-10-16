@tool
class_name FlagRegistry
extends Resource
## Todas las flags del juego (171+). El índice por id se arma una vez; en el editor se busca cada vez, así un id
## editado se ve enseguida.

const PATH := "res://data/flag_registry.tres"

@export var definitions: Array[FlagDefinition] = []:
	set(value):
		definitions = value
		_by_id.clear()

var _by_id: Dictionary[StringName, FlagDefinition] = {}


func has(id: StringName) -> bool:
	return _find(id) != null


func default_of(id: StringName) -> Variant:
	var definition := _find(id)
	return definition.default_value if definition else null


## Los ids que aparecen más de una vez (test_flags pide que no haya).
func duplicates() -> Array[StringName]:
	return Registries.duplicates(definitions.map(func(definition: FlagDefinition) -> StringName: return definition.id if definition else &""))


func _find(id: StringName) -> FlagDefinition:
	if Engine.is_editor_hint():
		for definition in definitions:
			if definition and definition.id == id:
				return definition
		return null
	if _by_id.is_empty():
		for definition in definitions:
			if definition:
				_by_id[definition.id] = definition
	return _by_id.get(id)
