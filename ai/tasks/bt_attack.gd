@tool
extends BTAction
## Un ataque: aviso (pose quieta) y golpe. Maneja el AttackRunner del agente;
## si la tarea se interrumpe (golpe, aturdido, muerte) la hitbox se apaga en _exit.

@export var attack: AttackData
@export var target_var: StringName = &"target"
## Cuánto dura el aviso antes del golpe.
@export var windup_time := 0.45
## En qué punto de la animación (0..1) se congela la pose del aviso.
@export_range(0.0, 1.0) var windup_pose := 0.15
## Quieto después del golpe: la ventana para contraatacar.
@export var recovery_time := 0.4

var _length := 1.0
var _striking := false


func _generate_name() -> String:
	return "Attack %s" % (attack.resource_path.get_file().get_basename() if attack else "?")


func _enter() -> void:
	_striking = false
	var anim_player: AnimationPlayer = agent.anim_player
	_length = anim_player.get_animation(attack.animation).length
	var target: Node3D = blackboard.get_var(target_var, null, false)
	if target:
		agent.face_towards(target.global_position)
	anim_player.play(attack.animation, 0.15)
	anim_player.seek(windup_pose * _length, true)
	anim_player.pause()
	if agent is Enemy:
		agent.flash.warn(windup_time)


func _tick(_delta: float) -> Status:
	if not _striking:
		if elapsed_time < windup_time:
			return RUNNING
		_striking = true
		agent.anim_player.play()
		agent.attack_runner.start(attack, _length, 1.0, windup_pose * _length)
	if elapsed_time >= windup_time + _length * (1.0 - windup_pose) + recovery_time:
		return SUCCESS
	return RUNNING


func _exit() -> void:
	agent.attack_runner.stop()
