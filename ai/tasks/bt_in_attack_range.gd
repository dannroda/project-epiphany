@tool
extends BTCondition

@export var target_var: StringName = &"target"


func _generate_name() -> String:
	return "InAttackRange(%s)" % LimboUtility.decorate_var(target_var)


func _tick(_delta: float) -> Status:
	var stored: Variant = blackboard.get_var(target_var, null, false)
	var target: Node3D = stored if is_instance_valid(stored) else null
	if target and agent.global_position.distance_to(target.global_position) <= agent.config.attack_range:
		return SUCCESS
	return FAILURE
