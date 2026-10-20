@tool
extends BTAction
## Un ataque: aviso (pose quieta) y golpe. Maneja el AttackRunner del agente;
## si la tarea se interrumpe (golpe, aturdido, muerte) la hitbox se apaga en _exit.
## El golpe y su timing salen de EntityConfig.attack del agente; `attack` es el de respaldo.

@export var attack: AttackData
@export var target_var: StringName = &"target"

var _attack: AttackData
var _length := 1.0
var _striking := false


func _generate_name() -> String:
	return "Attack %s" % (attack.resource_path.get_file().get_basename() if attack else "?")


func _enter() -> void:
	_striking = false
	var config: EntityConfig = agent.get(&"config")
	_attack = config.attack if config and config.attack else attack
	var anim_player: AnimationPlayer = agent.anim_player
	_length = anim_player.get_animation(_attack.animation).length
	var stored: Variant = blackboard.get_var(target_var, null, false)
	var target: Node3D = stored if is_instance_valid(stored) else null
	if target:
		agent.face_towards(target.global_position)
	anim_player.play(_attack.animation, 0.15)
	anim_player.seek(_attack.windup_pose * _length, true)
	anim_player.pause()
	if agent is Enemy:
		agent.telegraph(_attack.windup_time)


func _tick(_delta: float) -> Status:
	if not _striking:
		if elapsed_time < _attack.windup_time:
			return RUNNING
		_striking = true
		_end_telegraph()
		agent.anim_player.play()
		agent.attack_runner.start(_attack, _length, 1.0, _attack.windup_pose * _length)
	if elapsed_time >= _attack.windup_time + _length * (1.0 - _attack.windup_pose) + _attack.recovery_time:
		return SUCCESS
	return RUNNING


func _exit() -> void:
	_end_telegraph()
	agent.attack_runner.stop()


func _end_telegraph() -> void:
	if agent is Enemy:
		agent.end_telegraph()
