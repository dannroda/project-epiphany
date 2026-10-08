class_name Inventory
extends RefCounted

signal changed(id: StringName, count: int)

var _counts: Dictionary[StringName, int] = {}
var _capacity_bonus: Dictionary[StringName, int] = {}


func count(id: StringName) -> int:
	return _counts.get(id, 0)


func has(id: StringName, amount: int = 1) -> bool:
	return count(id) >= amount


func capacity(id: StringName) -> int:
	return Items.get_item(id).max_stack + _capacity_bonus.get(id, 0)


## Devuelve cuánto entró realmente.
func add(id: StringName, amount: int = 1) -> int:
	var added := mini(amount, capacity(id) - count(id))
	if added <= 0:
		return 0
	_counts[id] = count(id) + added
	changed.emit(id, _counts[id])
	return added


func remove(id: StringName, amount: int = 1) -> bool:
	if not has(id, amount):
		return false
	_counts[id] -= amount
	if _counts[id] == 0:
		_counts.erase(id)
	changed.emit(id, count(id))
	return true


func ids() -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(_counts.keys())
	return result
