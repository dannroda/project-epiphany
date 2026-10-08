@tool
extends BTAction
## Dispara un orbe reflejable hacia `target`.

@export var target_var: StringName = &"target"


func _generate_name() -> String:
	return "FireOrb ➜ %s" % LimboUtility.decorate_var(target_var)


func _tick(_delta: float) -> Status:
	var target: Node3D = blackboard.get_var(target_var, null, false)
	if target == null:
		return FAILURE
	agent.fire_at(target)
	return SUCCESS
