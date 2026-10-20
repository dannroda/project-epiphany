extends PlayerState
## Salto de la pluma (11.35): arco fijo de `height` (por encima de un escalón y de la onda del golpe de las manos del
## jefe), poco control en el aire y una sombra en el piso para ver dónde cae. El fondo redondeado de la cápsula se
## apoya en una esquina hasta ≈0,15 m por encima de sus pies: con más de 0,75 quedaría parado en el borde de una pirca.

const ANIMATION := &"MovementBasic/Jump_Full_Short"

@export var height := 0.68
## Velocidad horizontal con el stick a fondo.
@export var speed := 4.0
## Qué tan rápido el stick corrige la dirección en el aire (0 = nada).
@export var air_control := 2.0
## Salto largo (11.118): saltar en plena carrera de las sandalias sigue recto a esta velocidad, sin control en el aire.
@export var long_jump_speed := 8.6
## Tamaño de la sombra en el piso y en lo más alto.
@export var shadow_size := Vector2(0.9, 0.55)

var _velocity := Vector3.ZERO
var _start_y := 0.0
var _left_floor := false
var _elapsed := 0.0
var _shadow: Decal
var _long := false


func _enter() -> void:
	player.attack_runner.stop()
	_elapsed = 0.0
	_left_floor = false
	_start_y = player.global_position.y
	var long_jump: Array = blackboard.get_var(BB_LONG_JUMP, [], false)
	_long = not long_jump.is_empty() and long_jump[1] == Engine.get_physics_frames()
	blackboard.set_var(BB_LONG_JUMP, [])
	_velocity = long_jump[0] * long_jump_speed if _long else _wanted()
	if not _velocity.is_zero_approx():
		player.model.look_at(player.model.global_position - _velocity, Vector3.UP)
	player.velocity = _velocity + Vector3.UP * sqrt(2.0 * player.get_gravity().length() * height)
	var root := player.anim_tree.tree_root as AnimationNodeBlendTree
	(root.get_node(&"ItemAnim") as AnimationNodeAnimation).animation = ANIMATION
	player.anim_tree.set(&"parameters/UseItem/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	Feel.burst(&"dust", player.global_position + Vector3.UP * 0.1, Vector3.UP)
	Feel.sfx(&"roll", player.global_position)
	_shadow = player.get_node(^"%JumpShadow")
	_shadow.show()
	_place_shadow()


func _update(delta: float) -> void:
	_elapsed += delta
	if not _long:
		_velocity = _velocity.lerp(_wanted(), 1.0 - exp(-air_control * delta))
	player.velocity.x = _velocity.x
	player.velocity.z = _velocity.z
	player.move_and_slide()
	_place_shadow()
	if not player.is_on_floor():
		_left_floor = true
	elif _left_floor or _elapsed > 0.25:
		Feel.burst(&"dust", player.global_position + Vector3.UP * 0.1, Vector3.UP)
		dispatch("finished")


func _exit() -> void:
	_shadow.hide()
	player.anim_tree.set(&"parameters/UseItem/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)


## Atacar ahora clava el golpe en picada (Plunging), si ya la aprendió y despegó del piso.
func can_plunge() -> bool:
	return _left_floor and GameState.get_flag(Plunging.LEARNED)


## En el aire, ¿por encima de qué altura del piso de donde saltó?
func airborne_height() -> float:
	return player.global_position.y - _start_y


func _wanted() -> Vector3:
	var input: Vector2 = blackboard.get_var(BB_INPUT_DIR, Vector2.ZERO)
	return Vector3(input.x, 0.0, input.y).limit_length(1.0) * speed


func _place_shadow() -> void:
	var up := clampf(airborne_height() / height, 0.0, 1.0)
	var size := lerpf(shadow_size.x, shadow_size.y, up)
	_shadow.global_position = Vector3(player.global_position.x, _start_y + 0.5, player.global_position.z)
	_shadow.size = Vector3(size, _shadow.size.y, size)
