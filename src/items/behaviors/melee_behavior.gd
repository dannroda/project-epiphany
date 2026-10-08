class_name MeleeBehavior
extends ItemBehavior

@export var combo: Array[AttackData] = []


func get_attack(combo_index: int) -> AttackData:
	if combo.is_empty():
		return null
	return combo[combo_index % combo.size()]


func get_animation(_item: ItemData) -> StringName:
	return combo[0].animation if not combo.is_empty() else &""
