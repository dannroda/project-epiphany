@tool
extends BTCondition
## Fija `target` si el player está a la vista (rango de la ficha + línea de visión).

@export var target_var: StringName = &"target"
## Una vez visto, lo sigue viendo hasta este múltiplo del rango.
@export var lose_range_factor := 1.4


func _generate_name() -> String:
	return "FindPlayer ➜ %s" % LimboUtility.decorate_var(target_var)


func _tick(_delta: float) -> Status:
	var player := agent.get_tree().get_first_node_in_group(&"player") as Node3D
	var current: Node3D = blackboard.get_var(target_var, null, false)
	var max_range: float = agent.config.vision_range * (lose_range_factor if current else 1.0)
	if player and _visible(player, max_range):
		blackboard.set_var(target_var, player)
		return SUCCESS
	blackboard.set_var(target_var, null)
	return FAILURE


func _visible(player: Node3D, max_range: float) -> bool:
	if agent.global_position.distance_to(player.global_position) > max_range:
		return false
	var query := PhysicsRayQueryParameters3D.create(agent.global_position + Vector3.UP, player.global_position + Vector3.UP)
	query.exclude = [agent.get_rid()]
	query.collision_mask = 1
	var hit: Dictionary = agent.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.collider == player
