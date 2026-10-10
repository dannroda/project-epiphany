class_name Carrier
extends Node
## Lo que el player lleva sobre la cabeza (una bomba, una vasija): lo sostiene sin física, lo suelta o lo tira en arco.

## Carry_Throw lo suelta en esta fracción de la animación.
const THROW_RELEASE := 0.45
const BLEND_TIME := 0.12

@export var socket: Node3D
@export var anim_tree: AnimationTree
## Lo que tiene en las manos (espada, escudo): se guarda mientras carga.
@export var hide_while_carrying: Array[Node3D] = []

var carried: RigidBody3D
var _layer := 0
var _mask := 0
var _blend: Tween


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
	body.tree_exiting.connect(_on_gone, CONNECT_ONE_SHOT)


func is_carrying() -> bool:
	return is_instance_valid(carried)


func set_walking(walking: bool) -> void:
	if is_carrying() and anim_tree.get(&"parameters/CarryPhase/current_state") != &"Lift":
		anim_tree.set(&"parameters/CarryPhase/transition_request", "Walk" if walking else "Idle")


## Empieza Carry_Throw; quien llama tira con throw() a los `throw_delay()` segundos.
func start_throw() -> void:
	_play(&"Throw")


func throw_delay() -> float:
	return _length(&"Carry/Carry_Throw") * THROW_RELEASE


func throw_length() -> float:
	return _length(&"Carry/Carry_Throw")


## Sale de las manos y cae en `to` después de `flight_time` segundos.
func throw(to: Vector3, flight_time: float) -> void:
	var body := _release()
	if body == null:
		return
	var gravity := Vector3.DOWN * float(ProjectSettings.get_setting("physics/3d/default_gravity")) * body.gravity_scale
	body.linear_velocity = (to - body.global_position) / flight_time - gravity * flight_time * 0.5


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
	body.reparent(get_tree().current_scene)
	body.freeze = false
	body.collision_layer = _layer
	body.collision_mask = _mask
	return body


func _on_gone() -> void:
	carried = null
	_fade(0.0)


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
