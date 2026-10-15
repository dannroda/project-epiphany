class_name FillBehavior
extends ItemBehavior
## Botella vacía: apretando su botón junto a una vertiente, la llena con lo que da (agua bendita).


func can_use(ctx: ItemUseContext, _item: ItemData) -> bool:
	return Spring.reaching(ctx.user) != null


func use(ctx: ItemUseContext, _item: ItemData) -> void:
	var spring := Spring.reaching(ctx.user)
	if spring:
		spring.fill_bottle(ctx.source, ctx.user as PlayerCharacter)
