class_name ItemBehavior
extends Resource
## Sin estado: el recurso lo comparten todos los que usan el ítem.

@export var ammo: ItemData ## null = munición infinita
## En qué punto de la animación (0..1) se llama a use().
@export_range(0.0, 1.0) var use_at := 0.5


func get_animation(_item: ItemData) -> StringName:
	return &""


func can_use(_ctx: ItemUseContext, _item: ItemData) -> bool:
	return true


func use(_ctx: ItemUseContext, _item: ItemData) -> void:
	pass
