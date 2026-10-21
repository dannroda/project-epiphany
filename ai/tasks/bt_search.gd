@tool
extends BTAction
## Búsqueda del centinela: si perdió al player corre a donde lo vio por última vez (`last_seen_var`), mira a los lados y
## vuelve a su puesto (Enemy.home). Sin último lugar visto falla y deambula.

enum Step { GO, LOOK, BACK }

@export var last_seen_var: StringName = &"last_seen"
@export var alerted_var: StringName = &"alerted"
@export var run_animation: StringName = &"MovementBasic/Running_A"
@export var walk_animation: StringName = &"MovementBasic/Walking_A"
@export var idle_animation: StringName = &"General/Idle_A"
@export var look_time := 2.4
## Cuánto gira a cada lado al mirar (radianes).
@export var look_angle := 1.2
## Si no llega en este tiempo (algo lo tapa), sigue con el paso siguiente.
@export var give_up_after := 6.0

var _step := Step.GO
var _goal := Vector3.INF
var _left := 0.0
var _look_dir := Vector3.FORWARD


func _generate_name() -> String:
	return "Search %s" % LimboUtility.decorate_var(last_seen_var)


func _enter() -> void:
	var seen: Variant = blackboard.get_var(last_seen_var, null, false)
	_step = Step.GO
	_goal = seen if seen is Vector3 else Vector3.INF
	if _goal != Vector3.INF:
		_walk_to(_goal, Step.GO)


func _tick(delta: float) -> Status:
	if _goal == Vector3.INF and _step != Step.LOOK:
		return FAILURE
	if _step == Step.LOOK:
		_left -= delta
		var turn := sin((1.0 - _left / look_time) * TAU) * look_angle
		agent.face_towards(agent.global_position + _look_dir.rotated(Vector3.UP, turn))
		if _left <= 0.0:
			_walk_to(agent.home(), Step.BACK)
		return RUNNING
	_left -= delta
	var flat: Vector3 = agent.global_position - _goal
	flat.y = 0.0
	if flat.length() > 0.4 and _left > 0.0:
		var speed: float = agent.config.move_speed if _step == Step.GO else agent.config.wander_speed
		agent.move_toward_point(agent.path_to(_goal), speed)
		return RUNNING
	agent.stop_moving()
	if _step == Step.BACK:
		blackboard.set_var(alerted_var, false)
		return SUCCESS
	_step = Step.LOOK
	_left = look_time
	_look_dir = agent.facing()
	agent.anim_player.play(idle_animation, 0.2)
	blackboard.set_var(last_seen_var, null)
	return RUNNING


func _walk_to(point: Vector3, step: Step) -> void:
	_goal = point
	_step = step
	_left = give_up_after
	agent.anim_player.play(run_animation if step == Step.GO else walk_animation, 0.2)


func _exit() -> void:
	agent.stop_moving()
