class_name Carrier
extends Node
## Lo que el player lleva sobre la cabeza (una bomba, una vasija): lo sostiene sin física, lo suelta o lo tira en arco.

const BLEND_TIME := 0.12

@export_group("Ajuste")
## Carry_Throw lo suelta en esta fracción de la animación.
@export var throw_release := 0.45
## Lo tirado no choca con quien lo tiró hasta que se aleja.
@export var thrower_grace := 0.4
@export_group("")

@export var socket: Node3D
@export var anim_tree: AnimationTree
## Lo que tiene en las manos (espada, escudo): se guarda mientras carga.
@export var hide_while_carrying: Array[Node3D] = []
## Lo cargado destella y se ve tras las paredes como el cuerpo.
@export var flash: HitFlash

var carried: RigidBody3D
var _layer := 0
var _mask := 0
var _blend: Tween
var _overlays: Dictionary[MeshInstance3D, Material] = {}


## `lift` = agacharse a levantarlo del piso; sin eso aparece directo arriba (la bomba sale de la bolsa).
func carry(body: RigidBody3D, lift := false) -> void:
	drop()
	_play(&"Lift" if lift else &"Idle")
	carried = body
	_layer = body.collision_layer
	_mask = body.collision_mask
	body.collision_layer = 0
	body.collision_mask = 0
	body.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	body.freeze = true
	if body.is_inside_tree():
		body.reparent(socket, false)
	else:
		socket.add_child(body)
	body.transform = Transform3D.IDENTITY
	_cover(body)
	body.tree_exiting.connect(_on_gone, CONNECT_ONE_SHOT)


func is_carrying() -> bool:
	return is_instance_valid(carried)


func set_walking(walking: bool) -> void:
	if is_carrying() and anim_tree.get(&"parameters/CarryPhase/current_state") != &"Lift":
		anim_tree.set(&"parameters/CarryPhase/transition_request", "Walk" if walking else "Idle")


## Las manos en alto con un ítem recién conseguido (ItemGet_Raise sigue solo a ItemGet_Hold) hasta `lower_item()`.
func raise_item() -> void:
	drop()
	_play(&"ItemRaise")


## ItemGet_Lower; quien llama termina con drop() cuando acaba.
func lower_item() -> void:
	anim_tree.set(&"parameters/CarryPhase/transition_request", "ItemLower")


## Climb en loop mientras trepa; drop() lo termina.
func climb() -> void:
	drop()
	_play(&"Climb")


## Empieza Carry_Throw; quien llama tira con throw() a los `throw_delay()` segundos.
func start_throw() -> void:
	_play(&"Throw")


func throw_delay() -> float:
	return _length(&"Carry/Carry_Throw") * throw_release


func throw_length() -> float:
	return _length(&"Carry/Carry_Throw")


## Sale de las manos y cae en `to` después de `flight_time` segundos.
func throw(to: Vector3, flight_time: float) -> void:
	var body := _release()
	if body == null:
		return
	var gravity := Vector3.DOWN * float(ProjectSettings.get_setting("physics/3d/default_gravity")) * body.gravity_scale
	body.linear_velocity = (to - body.global_position) / flight_time - gravity * flight_time * 0.5
	var thrower := get_parent() as PhysicsBody3D
	if thrower:
		body.add_collision_exception_with(thrower)
		get_tree().create_timer(thrower_grace, false, true).timeout.connect(func() -> void:
			if is_instance_valid(body) and is_instance_valid(thrower):
				body.remove_collision_exception_with(thrower))


func drop() -> void:
	_release()
	_fade(0.0)


func _release() -> RigidBody3D:
	if not is_carrying():
		carried = null
		return null
	var body := carried
	carried = null
	body.tree_exiting.disconnect(_on_gone)
	_uncover()
	body.reparent(get_tree().current_scene)
	body.freeze = false
	if body is ThrownObject:
		(body as ThrownObject).liftable.show_outline(false)
	body.collision_layer = _layer
	body.collision_mask = _mask
	return body


func _on_gone() -> void:
	carried = null
	_overlays.clear()
	_fade(0.0)


func _cover(body: Node3D) -> void:
	if flash == null:
		return
	for mesh: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
		_overlays[mesh] = mesh.material_overlay
	flash.cover(body)


func _uncover() -> void:
	for mesh in _overlays:
		if is_instance_valid(mesh):
			mesh.material_overlay = _overlays[mesh]
	_overlays.clear()


func _play(phase: StringName) -> void:
	anim_tree.set(&"parameters/CarryPhase/transition_request", String(phase))
	_fade(1.0)
	_show_hands(false)


func _fade(amount: float) -> void:
	if amount == 0.0:
		_show_hands(true)
	if _blend:
		_blend.kill()
	_blend = create_tween()
	_blend.tween_property(anim_tree, "parameters/CarryBlend/blend_amount", amount, BLEND_TIME)


func _show_hands(present: bool) -> void:
	for node in hide_while_carrying:
		node.visible = present


func _length(animation: StringName) -> float:
	return (anim_tree.get_node(anim_tree.anim_player) as AnimationPlayer).get_animation(animation).length
