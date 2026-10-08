class_name PlaceBehavior
extends ItemBehavior
## Bombas: las coloca delante o, apuntando, las lanza en arco hacia ctx.throw_to.

@export var bomb_scene: PackedScene
@export var max_active := 2
@export var place_distance := 0.9
## Cuánto tarda en caer al punto apuntado.
@export var flight_time := 0.7


func get_animation(_item: ItemData) -> StringName:
	return &"General/Throw"


func can_use(ctx: ItemUseContext, _item: ItemData) -> bool:
	var has_ammo := ammo == null or ctx.inventory.has(ammo.id)
	return has_ammo and ctx.user.get_tree().get_nodes_in_group(&"bombs").size() < max_active


func use(ctx: ItemUseContext, _item: ItemData) -> void:
	if ammo:
		ctx.inventory.remove(ammo.id)
	var bomb: RigidBody3D = bomb_scene.instantiate()
	ctx.user.get_tree().current_scene.add_child(bomb)
	if ctx.throw_to == null:
		bomb.global_position = ctx.user.global_position + ctx.direction * place_distance + Vector3.UP * 0.3
		return
	var start := ctx.user.global_position + Vector3.UP * 1.4 + ctx.direction * 0.5
	var landing: Vector3 = ctx.throw_to + Vector3.UP * 0.3
	var gravity := Vector3.DOWN * float(ProjectSettings.get_setting("physics/3d/default_gravity")) * bomb.gravity_scale
	bomb.global_position = start
	bomb.linear_velocity = (landing - start) / flight_time - gravity * flight_time * 0.5
