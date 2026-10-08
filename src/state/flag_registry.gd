@tool
class_name FlagRegistry
extends Resource

@export var definitions: Array[FlagDefinition] = []


func has(id: StringName) -> bool:
	return _find(id) != null


func default_of(id: StringName) -> Variant:
	var definition := _find(id)
	return definition.default_value if definition else null


func _find(id: StringName) -> FlagDefinition:
	for definition in definitions:
		if definition and definition.id == id:
			return definition
	return null
