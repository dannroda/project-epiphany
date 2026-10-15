@tool
extends BTAction
## Huye de `target` hasta `safe_distance` por la navmesh y ahí se queda mirándolo; si se acerca, vuelve a huir.

@export var target_var: StringName = &"target"
@export var safe_distance := 8.0
@export var run_animation: StringName = &"Atoq/run"
@export var idle_animation: StringName = &"Atoq/idle"

var _running := false


func _generate_name() -> String:
	return "Flee %s m" % safe_distance


func _enter() -> void:
	_running = false
	agent.anim_player.play(idle_animation, 0.2)


func _tick(_delta: float) -> Status:
	var target: Variant = blackboard.get_var(target_var, null, false)
	if not is_instance_valid(target):
		return FAILURE
	var away: Vector3 = (agent.global_position - target.global_position) * Vector3(1, 0, 1)
	if away.length() >= safe_distance:
		if _running:
			_running = false
			agent.stop_moving()
			agent.anim_player.play(idle_animation, 0.2)
		agent.face_towards(target.global_position)
		return RUNNING
	if not _running:
		_running = true
		agent.anim_player.play(run_animation, 0.15)
	var map: RID = agent.nav_agent.get_navigation_map()
	var goal := NavigationServer3D.map_get_closest_point(map, agent.global_position + away.normalized() * safe_distance)
	agent.nav_agent.target_position = goal
	agent.move_toward_point(agent.nav_agent.get_next_path_position(), agent.config.move_speed)
	return RUNNING


func _exit() -> void:
	agent.stop_moving()
