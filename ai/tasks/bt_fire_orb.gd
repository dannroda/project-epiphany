@tool
extends BTAction
## Dispara un orbe reflejable hacia `target`.

@export var target_var: StringName = &"target"


func _generate_name() -> String:
	return "FireOrb ➜ %s" % LimboUtility.decorate_var(target_var)


func _tick(_delta: float) -> Status:
	var stored: Variant = blackboard.get_var(target_var, null, false)
	var target: Node3D = stored if is_instance_valid(stored) else null
	if target == null:
		return FAILURE
	agent.fire_at(target)
	return SUCCESS
