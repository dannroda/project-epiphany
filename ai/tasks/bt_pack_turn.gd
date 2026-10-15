@tool
extends BTCondition
## Le toca morder: pasó su descanso (`ready_var`, en segundos de Time) y nadie más de la jauría tiene el turno del objetivo.

@export var target_var: StringName = &"target"
@export var ready_var: StringName = &"bite_ready_at"


func _generate_name() -> String:
	return "PackTurn(%s)" % LimboUtility.decorate_var(target_var)


func _tick(_delta: float) -> Status:
	var target: Variant = blackboard.get_var(target_var, null, false)
	if not is_instance_valid(target):
		return FAILURE
	if Time.get_ticks_msec() / 1000.0 < blackboard.get_var(ready_var, 0.0, false):
		return FAILURE
	return SUCCESS if PackTurns.claim(target, agent) else FAILURE
