@tool
class_name ItemDatabase
extends Resource

## Las botellas son ítems únicos; lo que llevan (bottled) va en GameState.bottles.
const BOTTLES: Array[StringName] = [&"bottle_1", &"bottle_2", &"bottle_3", &"bottle_4"]
const EMPTY_BOTTLE := &"bottle_empty"

## Lo que se tiene y se lleva puesto al empezar una partida.
@export var new_game_equipment: Array[ItemData] = []
@export var items: Array[ItemData] = []:
	set(value):
		items = value
		_by_id.clear()

var _by_id: Dictionary[StringName, ItemData] = {}


## max_stack más lo que suman las mejoras de capacidad que `owns` (id -> bool) dice que se tienen.
func capacity(id: StringName, owns: Callable) -> int:
	var item := get_item(id)
	if item == null:
		return 0
	var total := item.max_stack
	for upgrade in items:
		if upgrade.capacity_for and upgrade.capacity_for.id == id and owns.call(upgrade.id):
			total += upgrade.capacity_bonus
	return total


func get_item(id: StringName) -> ItemData:
	if _by_id.is_empty():
		for item in items:
			if item:
				_by_id[item.id] = item
	return _by_id.get(id)


func has_item(id: StringName) -> bool:
	return get_item(id) != null
