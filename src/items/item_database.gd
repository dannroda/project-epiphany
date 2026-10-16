@tool
class_name ItemDatabase
extends Resource

## Las botellas son ítems únicos; lo que llevan (bottled) va en GameState.bottles.
const BOTTLES: Array[StringName] = [&"bottle_1", &"bottle_2", &"bottle_3", &"bottle_4"]
const EMPTY_BOTTLE := &"bottle_empty"

@export var items: Array[ItemData] = []:
	set(value):
		items = value
		_by_id.clear()

var _by_id: Dictionary[StringName, ItemData] = {}


func get_item(id: StringName) -> ItemData:
	if _by_id.is_empty():
		for item in items:
			if item:
				_by_id[item.id] = item
	return _by_id.get(id)


func has_item(id: StringName) -> bool:
	return get_item(id) != null
