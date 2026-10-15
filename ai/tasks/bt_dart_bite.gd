@tool
extends BTAction
## La mordida de la jauría: corre hasta `config.attack_range`, avisa, salta con el mordisco (config.attack, con su
## lunge) y se aleja hasta `retreat_distance`. Al salir suelta el turno y descansa `rest` segundos.

enum Phase { APPROACH, BITE, RETREAT }

@export var target_var: StringName = &"target"
@export var ready_var: StringName = &"bite_ready_at"
@export var run_animation: StringName = &"Atoq/run"
@export var retreat_distance := 4.0
@export var max_approach := 3.0
@export var max_retreat := 1.2
@export var rest := Vector2(2.0, 3.5)

var _phase := Phase.APPROACH
var _phase_time := 0.0
var _attack: AttackData
var _length := 1.0
var _striking := false
var _target: Node3D


func _generate_name() -> String:
	return "DartBite(%s)" % LimboUtility.decorate_var(target_var)


func _enter() -> void:
	var stored: Variant = blackboard.get_var(target_var, null, false)
	_target = stored if is_instance_valid(stored) else null
	_attack = agent.config.attack
	_length = agent.anim_player.get_animation(_attack.animation).length
	_set_phase(Phase.APPROACH)


func _tick(delta: float) -> Status:
	if not is_instance_valid(_target):
		return FAILURE
	_phase_time += delta
	var distance: float = agent.global_position.distance_to(_target.global_position)
	match _phase:
		Phase.APPROACH:
			if distance <= agent.config.attack_range:
				_set_phase(Phase.BITE)
			elif _phase_time > max_approach:
				return FAILURE
			else:
				agent.nav_agent.target_position = _target.global_position
				agent.move_toward_point(agent.nav_agent.get_next_path_position(), agent.config.move_speed)
		Phase.BITE:
			if not _striking:
				if _phase_time < _attack.windup_time:
					return RUNNING
				_striking = true
				agent.anim_player.play()
				agent.attack_runner.start(_attack, _length, 1.0, _attack.windup_pose * _length)
			var progress: float = agent.attack_runner.progress()
			agent.desired_velocity = agent.facing() * _attack.lunge if progress < _attack.active_to else Vector3.ZERO
			if _phase_time >= _attack.windup_time + _length * (1.0 - _attack.windup_pose) + _attack.recovery_time:
				_set_phase(Phase.RETREAT)
		Phase.RETREAT:
			if distance >= retreat_distance or _phase_time > max_retreat:
				return SUCCESS
			var away: Vector3 = (agent.global_position - _target.global_position) * Vector3(1, 0, 1)
			agent.desired_velocity = away.normalized() * agent.config.move_speed
			agent.face_towards(_target.global_position)
	return RUNNING


func _set_phase(phase: Phase) -> void:
	_phase = phase
	_phase_time = 0.0
	agent.stop_moving()
	if phase == Phase.BITE:
		_striking = false
		agent.face_towards(_target.global_position)
		agent.anim_player.play(_attack.animation, 0.1)
		agent.anim_player.seek(_attack.windup_pose * _length, true)
		agent.anim_player.pause()
		agent.flash.warn(_attack.windup_time)
	else:
		agent.anim_player.play(run_animation, 0.15)


func _exit() -> void:
	agent.attack_runner.stop()
	agent.stop_moving()
	PackTurns.release(_target, agent)
	blackboard.set_var(ready_var, Time.get_ticks_msec() / 1000.0 + randf_range(rest.x, rest.y))
