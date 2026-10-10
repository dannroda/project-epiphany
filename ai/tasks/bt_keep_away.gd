@tool
extends BTAction
## Si el objetivo se acerca más que `min_distance`, retrocede (mirándolo) hasta `safe_distance` o hasta chocar.

@export var target_var: StringName = &"target"
@export var min_distance := 3.5
@export var safe_distance := 6.0
@export var max_time := 1.5
@export var animation: StringName = &"MovementAdvanced/Walking_Backwards"


func _generate_name() -> String:
	return "KeepAway %s–%s m" % [min_distance, safe_distance]


func _enter() -> void:
	var target: Node3D = blackboard.get_var(target_var, null, false)
	if target and _distance(target) < min_distance:
		agent.anim_player.play(animation, 0.2)


func _tick(_delta: float) -> Status:
	var target: Node3D = blackboard.get_var(target_var, null, false)
	if target == null or (elapsed_time == 0.0 and _distance(target) >= min_distance):
		return FAILURE
	if _distance(target) >= safe_distance or elapsed_time >= max_time:
		return SUCCESS
	var away: Vector3 = agent.global_position - target.global_position
	away.y = 0.0
	agent.desired_velocity = away.normalized() * agent.config.move_speed
	agent.face_towards(target.global_position)
	return RUNNING


func _exit() -> void:
	agent.stop_moving()


func _distance(target: Node3D) -> float:
	return agent.global_position.distance_to(target.global_position)
