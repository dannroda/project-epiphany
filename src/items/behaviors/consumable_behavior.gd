class_name ConsumableBehavior
extends ItemBehavior

@export var heal: int = 0 ## HP; negativo = toda la vida
@export var leaves: ItemData ## Botella vacía al tomar la poción


func can_use(ctx: ItemUseContext, _item: ItemData) -> bool:
	var health: Health = ctx.user.get_node(^"Health")
	return heal == 0 or not health.is_full()


func use(ctx: ItemUseContext, item: ItemData) -> void:
	var health: Health = ctx.user.get_node(^"Health")
	if heal != 0:
		health.heal(health.max_health if heal < 0 else heal)
		Feel.sfx(&"heal", ctx.user.global_position)
	ctx.inventory.remove(item.id)
	if leaves:
		ctx.inventory.add(leaves.id)
