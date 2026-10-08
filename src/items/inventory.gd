class_name Inventory
extends RefCounted

signal changed(id: StringName, count: int)

var _counts: Dictionary[StringName, int] = {}


func count(id: StringName) -> int:
	return _counts.get(id, 0)


func has(id: StringName, amount: int = 1) -> bool:
	return count(id) >= amount


func capacity(id: StringName) -> int:
	var total := Items.get_item(id).max_stack
	for owned in _counts:
		var upgrade := Items.get_item(owned)
		if upgrade and upgrade.capacity_for and upgrade.capacity_for.id == id:
			total += upgrade.capacity_bonus
	return total


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


func clear() -> void:
	var previous := ids()
	_counts.clear()
	for id in previous:
		changed.emit(id, 0)


func ids() -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(_counts.keys())
	return result
