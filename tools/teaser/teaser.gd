extends Node3D
## Director del teaser (10.31): corre una toma de Shots desde uno de sus ángulos y cierra el juego. Va como autoload
## desde un override.cfg temporal; lo usan record.sh (Movie Maker), play.sh (Daniel juega la toma) y edit.sh.
## Args: --shot=<toma> --angle=<ángulo> --teaser-out=<carpeta del <toma>-<ángulo>.txt con "inicio duración">
## --teaser-mode=script|play|replay (play graba los inputs de Daniel en takes/<toma>.json; replay los repite)
## --teaser-list (escribe "TEASER <toma> <ángulo>" por cada combinación y sale).

const MOVES := [&"move_left", &"move_right", &"move_forward", &"move_backward"]
const TAKES := "res://tools/teaser/takes/"
const LEVEL_LAYER := 1
const WALL_MARGIN := 0.4
const NOT_RECORDED := [&"pause", &"map", &"debug_overlay", &"quicksave", &"quickload", &"toon", &"item_menu"]

@onready var _camera: Camera3D = $RailCamera
var _shot: TeaserShot
var _angle: TeaserAngle
var _mode := "script"
var _out := ""
var _clock := 0.0
var _phase := 0
var _settled_at := 0.0
var _start := 0.0
var _tick := 0
var _steps: Array[TeaserStep] = []
var _walk: TeaserStep
var _walk_until := 0.0
var _releases := {}
var _steering := false
var _path := PackedVector3Array()
var _path_index := 0
var _take: Array = []
var _cursor := 0
var _follow_ready := false


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	var angle_name := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shot = get_node_or_null("Shots/" + arg.get_slice("=", 1)) as TeaserShot
		elif arg.begins_with("--angle="):
			angle_name = arg.get_slice("=", 1)
		elif arg.begins_with("--teaser-out="):
			_out = arg.get_slice("=", 1)
		elif arg.begins_with("--teaser-mode="):
			_mode = arg.get_slice("=", 1)
		elif arg == "--teaser-list":
			_list.call_deferred()
			return
	if not _shot:
		set_process(false)
		set_physics_process(false)
		set_process_input(false)
		return
	if angle_name and _mode != "play":
		_angle = _shot.get_node_or_null(angle_name) as TeaserAngle
	elif _mode != "play" and not _shot.angles().is_empty():
		_angle = _shot.angles()[0]
	if _mode == "play":
		Engine.max_fps = 60
	elif _mode == "replay":
		_take = JSON.parse_string(FileAccess.get_file_as_string(TAKES + String(_shot.name) + ".json"))["events"]
	else:
		_steps = _shot.steps()
	SaveManager.load_scenario.call_deferred(_shot.scenario)


func _list() -> void:
	for shot: TeaserShot in $Shots.get_children():
		var names := shot.angles().map(func(angle: TeaserAngle) -> String: return String(angle.name))
		for angle_name in names if names else ["Juego"]:
			print("TEASER %s %s" % [shot.name, angle_name])
	get_tree().quit()


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
				_begin()
		2:
			_hide()
			var t := _clock - _start
			_frame(t, delta)
			if t >= _shot.length:
				_finish()


func _physics_process(_delta: float) -> void:
	if _phase == 2:
		_tick += 1


func _input(event: InputEvent) -> void:
	if _mode != "play" or _phase != 2 or event is InputEventAction:
		return
	for action in InputMap.get_actions():
		if event.is_action(action, true) and _recorded(action):
			var strength := event.get_action_strength(action, true) if event.is_pressed() else 0.0
			if _take and _take.back()[0] == _tick and _take.back()[1] == action:
				_take.back()[2] = strength
			else:
				_take.append([_tick, String(action), strength])


func _recorded(action: StringName) -> bool:
	return not String(action).begins_with("ui_") and not action in NOT_RECORDED and not String(action).substr(0, 3).ends_with("_")


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
	for step in _shot.steps():
		if step.kind == TeaserStep.Kind.EQUIP:
			GameState.assign_button(step.button, step.action)
	for pattern in _shot.freeze:
		for node in get_tree().current_scene.find_children(pattern, "", true, false):
			node.process_mode = Node.PROCESS_MODE_DISABLED
	if _shot.clear_enemies:
		for enemy: Node in get_tree().get_nodes_in_group(&"enemies"):
			enemy.queue_free()
	if _mode == "play":
		player.controls.captured = true
	var camera := _game_camera()
	if camera:
		if start:
			camera.room = null
		camera.snap_to_target()
		camera.make_current()


func _begin() -> void:
	if _angle and _angle.kind != TeaserAngle.Kind.GAME:
		_camera.fov = _angle.fov
		_camera.make_current()
		if _game_camera():
			_game_camera().set_cinematic(true, true)
	if _mode == "play":
		_player().controls.captured = false
		print("TEASER grabando %s: %.1f s" % [_shot.name, _shot.length])
	_start = _clock
	_phase = 2


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


func _hide() -> void:
	if _angle and _angle.kind != TeaserAngle.Kind.GAME and _phase == 2:
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


func _frame(t: float, delta: float) -> void:
	if _angle:
		_aim(_angle, clampf(t / _shot.length, 0.0, 1.0), delta)
	if _mode == "replay":
		while _cursor < _take.size() and _take[_cursor][0] <= _tick:
			var event: Array = _take[_cursor]
			_send(StringName(event[1]), event[2] > 0.0, event[2])
			_cursor += 1
		return
	for step in _steps.duplicate():
		if step.at <= t and (not step.on_floor or _grounded()):
			_steps.erase(step)
			_run(step, t)
	for action: StringName in _releases.keys():
		if t >= _releases[action]:
			_releases.erase(action)
			_send(action, false)
	_steer(t)


func _aim(angle: TeaserAngle, u: float, delta: float) -> void:
	var player := _player()
	var look := angle.get_node_or_null(^"Mira") as Node3D
	match angle.kind:
		TeaserAngle.Kind.RAIL:
			var from := angle.get_node(^"From") as Node3D
			var to := angle.get_node(^"To") as Node3D
			if look:
				_camera.global_position = from.global_position.lerp(to.global_position, u)
				_camera.look_at(look.global_position, Vector3.UP)
			else:
				_camera.global_transform = from.global_transform.interpolate_with(to.global_transform, u)
		TeaserAngle.Kind.FOLLOW:
			var aim := player.global_position + Vector3.UP * angle.look_height
			var goal := _clear_of_walls(aim, player.global_position + angle.offset)
			_camera.global_position = goal if not _follow_ready else _camera.global_position.lerp(goal, 1.0 - exp(-angle.smoothing * delta))
			_follow_ready = true
			_camera.look_at(aim, Vector3.UP)
		TeaserAngle.Kind.ORBIT:
			var center := look.global_position if look else player.global_position
			var turn := deg_to_rad(lerpf(angle.from_degrees, angle.to_degrees, u))
			var aim := center + Vector3.UP * angle.look_height
			_camera.global_position = _clear_of_walls(aim, center + Vector3(sin(turn), 0.0, cos(turn)) * angle.radius + Vector3.UP * angle.height)
			_camera.look_at(aim, Vector3.UP)


## Como una cámara en tercera persona: si una pared del nivel queda entre lo que se mira y la cámara, la cámara se
## pone delante de la pared.
func _clear_of_walls(aim: Vector3, wanted: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(aim, wanted, LEVEL_LAYER)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return wanted
	return hit.position + (aim - wanted).normalized() * WALL_MARGIN


func _run(step: TeaserStep, t: float) -> void:
	var player := _player()
	match step.kind:
		TeaserStep.Kind.WALK, TeaserStep.Kind.CHASE:
			_walk = step
			_walk_until = t + step.duration if step.duration > 0.0 else INF
			_path = PackedVector3Array()
			if step.kind == TeaserStep.Kind.WALK and step.navigate:
				_path = NavigationServer3D.map_get_path(get_world_3d().navigation_map, player.global_position, step.global_position, true)
				_path_index = 0
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
		while _path_index < _path.size() - 1 and _flat(_path[_path_index] - player.global_position) < 0.8:
			_path_index += 1
		if _path_index < _path.size():
			goal = _path[_path_index]
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


func _flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


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


func _send(action: StringName, pressed: bool, strength := 1.0) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	event.strength = strength if pressed else 0.0
	Input.parse_input_event(event)


func _finish() -> void:
	for action in MOVES:
		Input.action_release(action)
	if _mode == "play":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TAKES))
		var take := FileAccess.open(TAKES + String(_shot.name) + ".json", FileAccess.WRITE)
		take.store_string(JSON.stringify({shot = String(_shot.name), seed = _shot.rng_seed, events = _take}))
		take.close()
		print("TEASER toma guardada: %s (%d eventos)" % [TAKES + String(_shot.name) + ".json", _take.size()])
	elif _out:
		var file := FileAccess.open(_out.path_join("%s-%s.txt" % [_shot.name, _angle.name if _angle else &"Juego"]), FileAccess.WRITE)
		file.store_string("%.4f %.4f\n" % [_start, _shot.length])
		file.close()
	get_tree().quit()
