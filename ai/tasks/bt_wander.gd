@tool
extends BTAction
## Deambula: camina despacio a un punto al azar de la navmesh cerca de su lugar (Enemy.wander_point), se queda un rato
## y termina. Sin punto (navmesh lista todavía no, o todo tapado) solo hace la pausa.

@export var walk_animation: StringName = &"MovementBasic/Walking_A"
@export var idle_animation: StringName = &"General/Idle_A"
## Si no llega en este tiempo (algo lo tapa), deja de caminar y hace la pausa.
@export var give_up_after := 4.0

var _goal := Vector3.INF
var _walk_left := 0.0
var _pause_left := 0.0


func _generate_name() -> String:
	return "Wander"


func _enter() -> void:
	_goal = agent.wander_point()
	_walk_left = give_up_after
	_pause_left = randf_range(agent.config.wander_pause.x, agent.config.wander_pause.y)
	if _goal == Vector3.INF:
		_stop()
	else:
		agent.anim_player.play(walk_animation, 0.2)


func _tick(delta: float) -> Status:
	if _goal != Vector3.INF:
		_walk_left -= delta
		var flat: Vector3 = agent.global_position - _goal
		flat.y = 0.0
		if flat.length() < 0.3 or _walk_left <= 0.0:
			_stop()
		else:
			agent.move_toward_point(agent.path_to(_goal), agent.config.wander_speed)
			return RUNNING
	_pause_left -= delta
	return SUCCESS if _pause_left <= 0.0 else RUNNING


func _stop() -> void:
	_goal = Vector3.INF
	agent.stop_moving()
	agent.anim_player.play(idle_animation, 0.2)


func _exit() -> void:
	agent.stop_moving()
