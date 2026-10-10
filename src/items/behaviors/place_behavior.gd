class_name PlaceBehavior
extends ItemBehavior
## Bombas: tocar el botón la coloca delante (o la lanza hacia ctx.throw_to si se apunta con el stick derecho, el
## mouse o un objetivo); mantenerlo la levanta sobre la cabeza para apuntar y tirarla al soltar (estado AimingThrow).

@export var bomb_scene: PackedScene
@export var max_active := 2
@export var place_distance := 0.9
## Cuánto tarda en caer al punto apuntado.
@export var flight_time := 0.7
## Mantener el botón más que esto la levanta para apuntar.
@export var hold_time := 0.25


func get_animation(_item: ItemData) -> StringName:
	return &"General/Throw"


func can_use(ctx: ItemUseContext, _item: ItemData) -> bool:
	var has_ammo := ammo == null or ctx.inventory.has(ammo.id)
	return has_ammo and ctx.user.get_tree().get_nodes_in_group(&"bombs").size() < max_active


func use(ctx: ItemUseContext, _item: ItemData) -> void:
	var bomb := spawn(ctx)
	ctx.user.get_tree().current_scene.add_child(bomb)
	if ctx.throw_to == null:
		bomb.global_position = ctx.user.global_position + ctx.direction * place_distance + Vector3.UP * 0.3
		return
	bomb.global_position = ctx.user.global_position + Vector3.UP * 1.4 + ctx.direction * 0.5
	var gravity := Vector3.DOWN * float(ProjectSettings.get_setting("physics/3d/default_gravity")) * bomb.gravity_scale
	bomb.linear_velocity = (landing(ctx.throw_to) - bomb.global_position) / flight_time - gravity * flight_time * 0.5


## Gasta la munición y devuelve la bomba (sin agregar a la escena).
func spawn(ctx: ItemUseContext) -> RigidBody3D:
	if ammo:
		ctx.inventory.remove(ammo.id)
	return bomb_scene.instantiate()


func landing(point: Vector3) -> Vector3:
	return point + Vector3.UP * 0.3
