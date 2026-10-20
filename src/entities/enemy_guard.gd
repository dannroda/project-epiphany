class_name EnemyGuard
extends Node
## Escudo de frente: frena todo salvo explosiones y martillazos; un golpe que aturde le baja la guardia.

signal blocked(push: Vector3)

@export var body: Node3D
## Levanta el escudo; mientras ataca lo baja.
@export var pose: PoseOverlay
@export_range(0.0, 180.0, 1.0) var angle_deg := 70.0
## Un golpe que aturde (el golpe de escudo) le baja la guardia este tiempo.
@export_range(0.0, 10.0, 0.1, "or_greater") var break_time := 1.5

var _down_left := 0.0


func _ready() -> void:
	if pose:
		pose.influence = 1.0


func is_up() -> bool:
	return _down_left <= 0.0


## El escudo frena solo cuando se ve levantado.
func shield_up() -> bool:
	return is_up() and (pose == null or pose.influence > 0.5)


func lower(seconds: float) -> void:
	_down_left = maxf(_down_left, maxf(seconds, break_time))


func update(delta: float, raised: bool) -> void:
	_down_left = maxf(_down_left - delta, 0.0)
	if pose:
		pose.influence = move_toward(pose.influence, 1.0 if raised and is_up() else 0.0, delta / 0.15)


func stops(info: DamageInfo) -> bool:
	if not shield_up() or info.source == null or info.element == DamageInfo.EXPLOSIVE or info.strong:
		return false
	var to_source := (info.source.global_position - body.global_position) * Vector3(1, 0, 1)
	var forward := body.global_basis.z * Vector3(1, 0, 1)
	if to_source.is_zero_approx() or rad_to_deg(forward.angle_to(to_source)) > angle_deg:
		return false
	if info.stun_time > 0.0:
		_down_left = break_time
		Log.debug(&"combat", body.name, "bajó la guardia")
		Feel.sfx(&"deny", body.global_position)
	else:
		Feel.sfx(&"block", body.global_position)
		blocked.emit(-to_source.normalized() * info.knockback * 0.3)
	Feel.burst(&"sparks", body.global_position + Vector3.UP * 1.1 + to_source.normalized() * 0.5, to_source.normalized())
	return true
