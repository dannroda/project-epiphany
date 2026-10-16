extends Node3D
## Director del teaser (10.31): corre una toma de Shots y cierra el juego. Va como autoload desde un override.cfg
## temporal y se graba con Movie Maker; lo arma tools/teaser/record.sh, que después recorta y une las tomas.
## Args: --shot=<nombre de la toma> --teaser-out=<carpeta donde deja <toma>.txt con "inicio duración" en segundos>.

const MOVES := [&"move_left", &"move_right", &"move_forward", &"move_backward"]

@onready var _camera: Camera3D = $RailCamera
var _shot: TeaserShot
var _out := ""
var _clock := 0.0
var _phase := 0
var _settled_at := 0.0
var _start := 0.0
var _steps: Array[TeaserStep] = []
var _walk: TeaserStep
var _walk_until := 0.0
var _releases := {}
var _steering := false


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shot = get_node_or_null("Shots/" + arg.get_slice("=", 1)) as TeaserShot
		elif arg.begins_with("--teaser-out="):
			_out = arg.get_slice("=", 1)
	if not _shot:
		set_process(false)
		return
	_steps = _shot.steps()
	SaveManager.load_scenario.call_deferred(_shot.scenario)


func _process(delta: float) -> void:
	_clock += delta
	_drive_clouds()
	match _phase:
		0:
			if _game_ready():
				_set_up()
				_settled_at = _clock + _shot.settle
				_phase = 1
		1:
			_hide()
			_advance_boss()
			if _clock >= _settled_at:
				_camera_for_shot()
				_start = _clock
				_phase = 2
		2:
			_hide()
			var t := _clock - _start
			_frame(t)
			if t >= _shot.length:
				_finish()


func _game_ready() -> bool:
	var scene := get_tree().current_scene
	return scene and _player() and not get_tree().paused and not scene.scene_file_path.contains("/ui/")


func _player() -> PlayerCharacter:
	return get_tree().get_first_node_in_group(&"player") as PlayerCharacter


func _grounded() -> bool:
	var player := _player()
	return player.is_on_floor() and player.movement_state.get_active_state().name != &"Jumping"


func _game_camera() -> TopDownCamera:
	return get_tree().get_first_node_in_group(TopDownCamera.GROUP) as TopDownCamera


func _set_up() -> void:
	seed(_shot.rng_seed)
	AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Music"), true)
	for node in get_tree().current_scene.find_children("*", "", true, false):
		if node.get(&"rng") is RandomNumberGenerator:
			(node.get(&"rng") as RandomNumberGenerator).seed = _shot.rng_seed
	var player := _player()
	var start := _shot.get_node_or_null(^"Inicio") as Node3D
	if start:
		player.global_position = start.global_position
		player.velocity = Vector3.ZERO
		GameState.room_entry = start.global_position
		var face := -start.global_basis.z
		player.model.look_at(player.model.global_position - Vector3(face.x, 0.0, face.z), Vector3.UP)
	for step in _steps:
		if step.kind == TeaserStep.Kind.EQUIP:
			GameState.assign_button(step.button, step.action)
	for pattern in _shot.freeze:
		for node in get_tree().current_scene.find_children(pattern, "", true, false):
			node.process_mode = Node.PROCESS_MODE_DISABLED
	if _shot.clear_enemies:
		for enemy: Node in get_tree().get_nodes_in_group(&"enemies"):
			enemy.queue_free()
	var camera := _game_camera()
	if camera:
		if start:
			camera.room = null
		camera.snap_to_target()
		camera.make_current()


func _advance_boss() -> void:
	var boss := get_tree().current_scene.find_children("*", "Boss", true, false).pop_front() as Boss
	if not boss or not boss.phases.is_active() or boss.phase() >= _shot.boss_phase:
		return
	boss.presents_phases = false
	if boss.phase() == 2:
		boss.phases.dispatch(&"enraged")
		return
	for hand: BossHand in [boss.hand_left, boss.hand_right]:
		if hand.state != BossHand.State.DOWN:
			var hit := DamageInfo.new()
			hit.amount = hand.health.max_health
			hit.team = EntityConfig.Team.PLAYER
			hand.health.invulnerability_time = 0.0
			hand.stun(1.0)
			hand.hurtbox.receive(hit)


func _camera_for_shot() -> void:
	if _shot.view == TeaserShot.View.RAIL:
		_camera.fov = _shot.fov
		_camera.make_current()


func _hide() -> void:
	if _shot.view == TeaserShot.View.RAIL:
		for node in get_tree().root.find_children("*", "CanvasLayer", true, false):
			node.hide()
	else:
		DebugOverlay.hide()
	if not _shot.show_player:
		for node in get_tree().get_nodes_in_group(&"player"):
			node.hide()


func _drive_clouds() -> void:
	var scene := get_tree().current_scene
	if not scene:
		return
	for env: WorldEnvironment in scene.find_children("*", "WorldEnvironment", true, false):
		if env.compositor:
			for effect in env.compositor.compositor_effects:
				if effect and &"time_override" in effect:
					effect.set(&"time_override", _clock)


func _frame(t: float) -> void:
	if _shot.view == TeaserShot.View.RAIL:
		_rail(clampf(t / _shot.length, 0.0, 1.0))
	for step in _steps.duplicate():
		if step.at <= t and (not step.on_floor or _grounded()):
			_steps.erase(step)
			_run(step, t)
	for action: StringName in _releases.keys():
		if t >= _releases[action]:
			_releases.erase(action)
			_send(action, false)
	_steer(t)


func _rail(u: float) -> void:
	var from := _shot.get_node(^"From") as Node3D
	var to := _shot.get_node(^"To") as Node3D
	var look := _shot.get_node_or_null(^"Mira") as Node3D
	if look:
		_camera.global_position = from.global_position.lerp(to.global_position, u)
		_camera.look_at(look.global_position, Vector3.UP)
	else:
		_camera.global_transform = from.global_transform.interpolate_with(to.global_transform, u)


func _run(step: TeaserStep, t: float) -> void:
	var player := _player()
	match step.kind:
		TeaserStep.Kind.WALK, TeaserStep.Kind.CHASE:
			_walk = step
			_walk_until = t + step.duration if step.duration > 0.0 else INF
		TeaserStep.Kind.PRESS:
			_send(step.action, true)
			_releases[step.action] = t + 0.05
		TeaserStep.Kind.HOLD:
			_send(step.action, true)
			_releases[step.action] = t + step.duration
		TeaserStep.Kind.LOCK:
			var target := get_tree().current_scene.get_node_or_null(step.target) as Node3D if step.target else null
			if target:
				player.targeting.set_target(target)
			else:
				player.targeting.lock_best_target()
		TeaserStep.Kind.UNLOCK:
			player.targeting.clear()


func _steer(t: float) -> void:
	var dir := Vector2.ZERO
	if _walk and t < _walk_until:
		var player := _player()
		var goal := _walk.global_position
		var stop := 0.3
		if _walk.kind == TeaserStep.Kind.CHASE:
			var enemy := _nearest_enemy(player.global_position)
			goal = enemy.global_position if enemy else player.global_position
			stop = _walk.reach
		var to := Vector2(goal.x - player.global_position.x, goal.z - player.global_position.z)
		if to.length() > stop:
			dir = to.normalized()
		elif _walk.kind == TeaserStep.Kind.WALK:
			_walk = null
	elif _walk:
		_walk = null
	if dir or _steering:
		_axis(&"move_left", &"move_right", dir.x)
		_axis(&"move_forward", &"move_backward", dir.y)
	_steering = dir != Vector2.ZERO


func _axis(negative: StringName, positive: StringName, value: float) -> void:
	for pair in [[negative, -value], [positive, value]]:
		if pair[1] > 0.05:
			Input.action_press(pair[0], pair[1])
		else:
			Input.action_release(pair[0])


func _nearest_enemy(from: Vector3) -> Node3D:
	var best: Node3D
	for enemy: Node3D in get_tree().get_nodes_in_group(&"enemies"):
		if enemy.is_visible_in_tree() and (not best or from.distance_to(enemy.global_position) < from.distance_to(best.global_position)):
			best = enemy
	return best


func _send(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	event.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(event)


func _finish() -> void:
	for action in MOVES:
		Input.action_release(action)
	if _out:
		var file := FileAccess.open(_out.path_join(String(_shot.name) + ".txt"), FileAccess.WRITE)
		file.store_string("%.4f %.4f\n" % [_start, _shot.length])
		file.close()
	get_tree().quit()
