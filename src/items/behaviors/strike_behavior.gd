class_name StrikeBehavior
extends ItemBehavior
## Martillo (11.191): un golpe de dos manos que en use_at clava `strike_scene` en el piso, `reach` hacia donde mira el
## player, con el daño del ítem.

@export var animation: StringName = &"CombatMelee/Melee_2H_Attack_Chop"
@export var strike_scene: PackedScene
@export var reach := 1.2


func get_animation(_item: ItemData) -> StringName:
	return animation


func use(ctx: ItemUseContext, item: ItemData) -> void:
	var strike := strike_scene.instantiate() as Hitbox
	var player := ctx.user as PlayerCharacter
	strike.team = player.hurtbox.team if player else EntityConfig.Team.PLAYER
	strike.damage_factory = item.make_damage.bind(ctx.user)
	Spawns.root(ctx.user).add_child(strike)
	var forward := (player.model.global_basis.z if player else ctx.direction) * Vector3(1, 0, 1)
	strike.global_position = ctx.user.global_position + forward.normalized() * reach
