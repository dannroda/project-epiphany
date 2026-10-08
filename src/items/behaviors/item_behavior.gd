class_name ItemBehavior
extends Resource
## Sin estado: el recurso lo comparten todos los que usan el ítem.

@export var ammo: ItemData ## null = munición infinita


func get_animation(_item: ItemData) -> StringName:
	return &""


func can_use(_ctx: ItemUseContext, _item: ItemData) -> bool:
	return true


func use(_ctx: ItemUseContext, _item: ItemData) -> void:
	pass
