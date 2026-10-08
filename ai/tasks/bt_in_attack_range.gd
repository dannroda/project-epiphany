@tool
extends BTCondition

@export var target_var: StringName = &"target"


func _generate_name() -> String:
	return "InAttackRange(%s)" % LimboUtility.decorate_var(target_var)


func _tick(_delta: float) -> Status:
	var target: Node3D = blackboard.get_var(target_var, null, false)
	if target and agent.global_position.distance_to(target.global_position) <= agent.config.attack_range:
		return SUCCESS
	return FAILURE
