@tool
extends BTAction
## Persigue a `target` con el NavigationAgent3D del agente hasta quedar a rango de ataque.

@export var target_var: StringName = &"target"
@export var animation: StringName = &"MovementBasic/Running_A"


func _generate_name() -> String:
	return "MoveTo(%s)" % LimboUtility.decorate_var(target_var)


func _enter() -> void:
	agent.anim_player.play(animation, 0.2)


func _tick(_delta: float) -> Status:
	var target: Node3D = blackboard.get_var(target_var, null, false)
	if target == null:
		return FAILURE
	if agent.global_position.distance_to(target.global_position) <= agent.config.attack_range:
		return SUCCESS
	agent.nav_agent.target_position = target.global_position
	agent.move_toward_point(agent.nav_agent.get_next_path_position(), agent.config.move_speed)
	return RUNNING


func _exit() -> void:
	agent.stop_moving()
