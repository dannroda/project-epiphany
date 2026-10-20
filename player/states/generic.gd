class_name PlayerState
extends LimboState

const SPEED = 10.0
## Los estados que esperan una animación (levantar, tirar, usar un ítem, tensar el arco) siguen hasta esta parte de su largo.
const ANIM_PART := 0.5
## Claves del blackboard de la máquina de estados del player.
const BB_TARGET := &"target"
const BB_IS_BLOCKING := &"is_blocking"
const BB_INPUT_DIR := &"input_dir"
const BB_ITEM_BUTTON := &"item_button"
const BB_GRABBED_BY := &"grabbed_by"
const BB_GREAT_SPIN := &"great_spin"

## Al cruzar de sala pasa a Transition.
@export var follows_room_transition := true
## Una mano del jefe lo puede agarrar.
@export var can_be_grabbed := true
## Un golpe lo pasa a Hurt; si no, el daño entra igual pero sigue en este estado (cruce de sala, levantar un ítem).
@export var can_be_hurt := true
## Puede hablar, abrir cofres y levantar cosas.
@export var can_interact := false
## Manteniendo Z sube el escudo.
@export var can_guard := false
const BB_LONG_JUMP := &"long_jump"
const BB_TRANSITION_TIME := &"transition_time"
const BB_TRANSITION_DIR := &"transition_dir"
const BB_PUSH_DIR := &"push_dir"
const BB_PUSH_BLOCK := &"push_block"
const BB_LIFTABLE := &"liftable"
const BB_LAST_HIT := &"last_hit"
const BB_GOT_ITEM := &"got_item"
const BB_GOT_AMOUNT := &"got_amount"
const BB_CLIMB_PATH := &"climb_path"
const BB_CLIMB_FACE := &"climb_face"

var velocity:Vector3 :
	get:
		return agent.velocity

var player:PlayerCharacter:
	get:
		if agent is PlayerCharacter:
			return get_root().player
		return player


## Fijado a un objetivo: el cuerpo mira al objetivo y las piernas mezclan el strafe según hacia dónde camina.
func move_locked(input: Vector2, speed: float, target: Node3D, face_model := true) -> void:
	var move_dir := Vector3(input.x, 0, input.y).normalized()
	player.velocity.x = move_dir.x * speed * player.ground_speed
	player.velocity.z = move_dir.z * speed * player.ground_speed
	player.move_and_slide()
	var to_target := target.global_position - player.global_position
	to_target.y = 0
	if to_target.is_zero_approx():
		return
	var fwd := to_target.normalized()
	player.look_at(player.global_position + fwd, Vector3.UP)
	if face_model:
		player.model.rotation = Vector3(0, PI, 0)
	var character_right := Vector3.UP.cross(-fwd)
	player.anim_tree["parameters/Targeting/blend_position"] = Vector2(move_dir.dot(character_right), -move_dir.dot(fwd))


## Al cruzar de sala no camina hacia adentro (el gancho tirando de él termina al lado del poste).
func blocks_room_transition() -> bool:
	return false


## Piernas en modo strafe (fijado) o normal.
func set_locked_legs(locked: bool) -> void:
	var current: String = player.anim_tree.get(&"parameters/Combat/current_state")
	var wanted := "Targeting" if locked else "Normal"
	if current != wanted:
		player.anim_tree.set(&"parameters/Combat/transition_request", wanted)
