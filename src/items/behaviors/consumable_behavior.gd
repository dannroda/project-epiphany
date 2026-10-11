class_name ConsumableBehavior
extends ItemBehavior

@export var heal: int = 0 ## HP; negativo = toda la vida
@export var leaves: ItemData ## Botella vacía al tomar la poción
@export var ward_time := 0.0 ## Segundos de bendición (Health.ward); con bendición se puede tomar con la vida llena


func can_use(ctx: ItemUseContext, _item: ItemData) -> bool:
	var health: Health = ctx.user.get_node(^"Health")
	return heal == 0 or ward_time > 0.0 or not health.is_full()


func use(ctx: ItemUseContext, item: ItemData) -> void:
	var health: Health = ctx.user.get_node(^"Health")
	if heal != 0:
		health.heal(health.max_health if heal < 0 else heal)
		Feel.sfx(&"heal", ctx.user.global_position)
	if ward_time > 0.0:
		health.ward(ward_time)
		Blessing.attach(ctx.user, health)
	if leaves and ctx.inventory == GameState.inventory:
		GameState.swap_item(item.id, leaves)
		return
	ctx.inventory.remove(item.id)
	if leaves:
		ctx.inventory.add(leaves.id)
