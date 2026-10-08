@tool
extends BTAction
## Gira la cabeza de la torreta hacia `target`; SUCCESS cuando lo mira.

@export var target_var: StringName = &"target"


func _generate_name() -> String:
	return "TurnTo %s" % LimboUtility.decorate_var(target_var)


func _tick(delta: float) -> Status:
	var target: Node3D = blackboard.get_var(target_var, null, false)
	if target == null:
		return FAILURE
	return SUCCESS if agent.turn_towards(target.global_position, delta) else RUNNING
