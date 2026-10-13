@tool
extends BTAction
## Arquero: tensa (el aviso: brilla y sigue al objetivo), dispara una flecha y se queda quieto un momento.

const ARROW := preload("res://src/items/arrow/arrow.tscn")

@export var target_var: StringName = &"target"
## Mientras tensa queda en true: KeepAway no lo interrumpe.
@export var drawing_var: StringName = &"drawing"
@export var draw_time := 1.0
@export var arrow_speed := 13.0
@export var recovery_time := 0.7

var _shot := false
var _bow: BowModel


func _generate_name() -> String:
	return "ShootArrow %ss" % draw_time


func _setup() -> void:
	_bow = agent.find_child("Bow", true, false) as BowModel


func _enter() -> void:
	_shot = false
	blackboard.set_var(drawing_var, true)
	agent.stop_moving()
	agent.anim_player.play(&"CombatRanged/Ranged_Bow_Draw", 0.15)
	agent.flash.warn(draw_time)
	if _bow:
		_bow.nocked = true


func _tick(_delta: float) -> Status:
	var target := _target()
	if not _shot:
		if target == null:
			return FAILURE
		_aim_at(target)
		if _bow:
			_bow.draw = elapsed_time / draw_time
		if elapsed_time < draw_time:
			return RUNNING
		_shoot(target)
	return SUCCESS if elapsed_time >= draw_time + recovery_time else RUNNING


func _exit() -> void:
	blackboard.set_var(drawing_var, false)
	_release_bow()


func _aim_at(target: Node3D) -> void:
	agent.face_towards(target.global_position)


func _shoot(target: Node3D) -> void:
	_shot = true
	blackboard.set_var(drawing_var, false)
	agent.anim_player.play(&"CombatRanged/Ranged_Bow_Release", 0.05)
	_release_bow()
	var info: DamageInfo = agent.config.make_damage(agent)
	info.reflectable = true
	var arrow: Projectile = ARROW.instantiate()
	agent.get_tree().current_scene.add_child(arrow)
	var from: Vector3 = agent.global_position + Vector3.UP * 1.2
	var aim_point := target.global_position + Vector3.UP * 1.0
	var direction := aim_point - from
	direction.y = 0.0
	arrow.launch(from + direction.normalized() * 0.6, direction.normalized() * arrow_speed, info)
	Feel.sfx(&"click", from)


func _release_bow() -> void:
	if is_instance_valid(_bow):
		_bow.draw = 0.0
		_bow.nocked = false


## Puede ser un player ya liberado (cambio de escena): entonces no hay objetivo.
func _target() -> Node3D:
	var target: Variant = blackboard.get_var(target_var, null, false)
	return target if is_instance_valid(target) else null
