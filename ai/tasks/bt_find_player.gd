@tool
extends BTCondition
## Fija `target` con el player a la vista (rango de la ficha + línea de visión): sigue al que ya tenía mientras lo vea;
## si no, el más cercano que vea.

@export var target_var: StringName = &"target"
## Una vez visto, lo sigue viendo hasta este múltiplo del rango.
@export var lose_range_factor := 1.4
## Dónde lo vio por última vez (lo usa la búsqueda del centinela).
@export var last_seen_var: StringName = &"last_seen"


func _generate_name() -> String:
	return "FindPlayer ➜ %s" % LimboUtility.decorate_var(target_var)


func _tick(_delta: float) -> Status:
	var current: Variant = blackboard.get_var(target_var, null, false)
	if is_instance_valid(current) and current is PlayerCharacter and not current.is_dead:
		if _visible(current, agent.config.vision_range * lose_range_factor):
			blackboard.set_var(last_seen_var, current.global_position)
			return SUCCESS
	var candidates := Players.alive()
	candidates.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return agent.global_position.distance_squared_to(a.global_position) < agent.global_position.distance_squared_to(b.global_position))
	for player in candidates:
		if _visible(player, agent.config.vision_range):
			blackboard.set_var(target_var, player)
			blackboard.set_var(last_seen_var, player.global_position)
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
