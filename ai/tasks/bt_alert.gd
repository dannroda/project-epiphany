@tool
extends BTAction
## Alerta del centinela: la primera vez que ve al player se frena, lo mira y muestra el ! (%Alert) antes de pelear.
## Queda alerta (`alerted_var`) hasta terminar de buscarlo; ya alerta, falla y pasa a atacar o perseguir.

@export var target_var: StringName = &"target"
@export var alerted_var: StringName = &"alerted"
@export var alert_time := 0.7
@export var animation: StringName = &"General/Idle_A"

var _left := 0.0
var _skip := false


func _generate_name() -> String:
	return "Alert ➜ %s" % LimboUtility.decorate_var(alerted_var)


func _enter() -> void:
	_skip = blackboard.get_var(alerted_var, false, false)
	if _skip:
		return
	_left = alert_time
	agent.stop_moving()
	agent.anim_player.play(animation, 0.15)
	_show_mark(true)


func _tick(delta: float) -> Status:
	if _skip:
		return FAILURE
	var target: Variant = blackboard.get_var(target_var, null, false)
	if is_instance_valid(target):
		agent.face_towards(target.global_position)
	_left -= delta
	if _left > 0.0:
		return RUNNING
	blackboard.set_var(alerted_var, true)
	return SUCCESS


func _exit() -> void:
	_show_mark(false)


func _show_mark(on: bool) -> void:
	var mark := agent.get_node_or_null(^"%Alert") as Node3D
	if mark:
		mark.visible = on
