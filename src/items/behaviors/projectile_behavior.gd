class_name ProjectileBehavior
extends ItemBehavior
## Dispara `projectile_scene` hacia ctx.direction. La munición la descuenta acá.

@export var projectile_scene: PackedScene
@export var speed: float = 20.0


func can_use(ctx: ItemUseContext, _item: ItemData) -> bool:
	return ammo == null or ctx.inventory.has(ammo.id)


func use(ctx: ItemUseContext, item: ItemData) -> void:
	if ammo:
		ctx.inventory.remove(ammo.id)
	var info := item.make_damage(ctx.user)
	var config: EntityConfig = ctx.user.get(&"config")
	if config:
		info.team = config.team
	Projectile.fire(projectile_scene, ctx.user, ctx.origin, ctx.direction * speed, info)
