@tool
extends BTCondition
## Fija `target` con el player a la vista (rango de la ficha + línea de visión): sigue al que ya tenía mientras lo vea
## o mientras estén los dos en la misma sala de dungeon (en el overworld, mientras el player siga en su región); si no,
## el más cercano que vea.

@export var target_var: StringName = &"target"
## Una vez visto, lo sigue viendo hasta este múltiplo del rango.
@export var lose_range_factor := 1.4
## Dónde lo vio por última vez (lo usa la búsqueda del centinela).
@export var last_seen_var: StringName = &"last_seen"

var _ray := PhysicsRayQueryParameters3D.new()
var _hit := PhysicsIntersectRayResult3D.new()


func _generate_name() -> String:
	return "FindPlayer ➜ %s" % LimboUtility.decorate_var(target_var)


func _tick(_delta: float) -> Status:
	var current: Variant = blackboard.get_var(target_var, null, false)
	if is_instance_valid(current) and current is PlayerCharacter and not current.is_dead:
		if _visible(current, agent.config.vision_range * lose_range_factor) or (agent is Enemy and agent.shares_room(current.global_position)):
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
	_ray.from = agent.global_position + Vector3.UP
	_ray.to = player.global_position + Vector3.UP
	_ray.exclude = [agent.get_rid()]
	_ray.collision_mask = 1
	return not agent.get_world_3d().direct_space_state.intersect_ray_into(_ray, _hit) or _hit.collider == player
