extends "res://player/states/attacking.gd"
## Contraataque (Counter): rueda por el costado del enemigo fijado, o le salta por encima si es grande
## (EntityConfig.counter_vault), y le pega por la espalda con `attack`. No recibe daño hasta que pega.

@export var attack: AttackData
## Segundos hasta quedar a su espalda.
@export var move_time := 0.32
## A cuánto de su centro queda, detrás.
@export var behind_distance := 1.3
@export var vault_height := 1.4
## Lo que dura la invulnerabilidad después de llegar.
@export var cover_after := 0.25

const VAULT_ANIMATION := &"MovementBasic/Jump_Full_Short"

var _target: Node3D
var _center := Vector3.ZERO
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _start_angle := 0.0
var _arc := 0.0
var _start_radius := 0.0
var _vault := false
var _elapsed := 0.0
var _moving := false


func _setup() -> void:
	pass


func _enter() -> void:
	_target = player.counter.spend()
	_attack = null
	_elapsed = 0.0
	_moving = is_instance_valid(_target)
	player.attack_runner.stop()
	if not _moving:
		super._enter()
		return
	_from = player.global_position
	_center = Vector3(_target.global_position.x, _from.y, _target.global_position.z)
	var back := -_target.global_basis.z * Vector3(1, 0, 1)
	if back.is_zero_approx():
		back = (_from - _center).normalized()
	_to = _center + back.normalized() * behind_distance
	var config: Variant = _target.get(&"config")
	_vault = config is EntityConfig and config.counter_vault
	var offset := _from - _center
	_start_radius = maxf(offset.length(), 0.9)
	_start_angle = atan2(offset.x, offset.z)
	_arc = wrapf(atan2(back.x, back.z) - _start_angle, -PI, PI)
	if absf(_arc) > PI - 0.2:
		var input: Vector2 = blackboard.get_var(BB_INPUT_DIR, Vector2.ZERO)
		var right := Vector3.UP.cross(-offset.normalized())
		_arc = absf(_arc) * (1.0 if Vector3(input.x, 0.0, input.y).dot(right) >= 0.0 else -1.0)
	player.add_collision_exception_with(_target)
	player.health.make_invulnerable(move_time + cover_after)
	player.dodge_ghosts.start(move_time)
	if _vault:
		var root := player.anim_tree.tree_root as AnimationNodeBlendTree
		(root.get_node(&"ItemAnim") as AnimationNodeAnimation).animation = VAULT_ANIMATION
		player.anim_tree.set(&"parameters/UseItem/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	else:
		player.anim_tree.set(&"parameters/DodgeDir/transition_request", "Left" if _arc > 0.0 else "Right")
		player.anim_tree.set(&"parameters/Dodge/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	Feel.burst(&"dust", player.global_position + Vector3.UP * 0.1, Vector3.UP)
	Feel.sfx(&"roll", player.global_position)


func _update(delta: float) -> void:
	if not _moving:
		super._update(delta)
		return
	_elapsed += delta
	var t := clampf(_elapsed / move_time, 0.0, 1.0)
	var goal: Vector3
	if _vault:
		goal = _from.lerp(_to, t)
		goal.y = _from.y + sin(t * PI) * vault_height
	else:
		var angle := _start_angle + _arc * t
		goal = _center + Vector3(sin(angle), 0.0, cos(angle)) * lerpf(_start_radius, behind_distance, t)
		goal.y = player.global_position.y
	player.velocity = (goal - player.global_position) / delta
	player.move_and_slide()
	if is_instance_valid(_target):
		var look := _target.global_position - player.global_position
		look.y = 0.0
		if not look.is_zero_approx():
			player.model.look_at(player.model.global_position - look, Vector3.UP)
	if t >= 1.0:
		_moving = false
		player.velocity = Vector3.ZERO
		if _vault:
			player.anim_tree.set(&"parameters/UseItem/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)
		super._enter()


func _exit() -> void:
	if is_instance_valid(_target):
		player.remove_collision_exception_with(_target)
	_moving = false
	super._exit()


func _pick_attack() -> AttackData:
	return attack


func _on_attack_finished() -> void:
	if not _moving:
		super._on_attack_finished()
