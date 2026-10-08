@tool
extends BTAction
## Aviso antes de disparar: el ojo brilla cada vez más mientras sigue al objetivo.

@export var target_var: StringName = &"target"
@export var duration := 0.9


func _generate_name() -> String:
	return "ChargeShot %ss" % duration


func _tick(delta: float) -> Status:
	var target: Node3D = blackboard.get_var(target_var, null, false)
	if target == null:
		agent.set_charge(0.0)
		return FAILURE
	agent.turn_towards(target.global_position, delta)
	agent.set_charge(clampf(elapsed_time / duration, 0.0, 1.0))
	return SUCCESS if elapsed_time >= duration else RUNNING


func _exit() -> void:
	if not agent.is_dead and elapsed_time < duration:
		agent.set_charge(0.0)
