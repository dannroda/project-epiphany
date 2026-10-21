extends "res://tests/test_case.gd"
## El player se siente igual que cuando su máquina de estados se actualizaba dos veces por cuadro: duraciones de cada
## estado (en cuadros de física, ±1) y distancias (±5 cm) medidas antes del arreglo.

const LEVEL := "res://levels/test/test.tscn"
const FAR := Vector3(200, 0, 0)
const POST := preload("res://src/world/puzzles/hook_post.tscn")
const FRAMES := 1
const METERS := 0.05
const EXPECTED := {
	"walk": {"guard_walk_1s": 3.901, "slide": 0.167, "start_frames": 2, "walk_1s": 9.999},
	"roll": {"dist": 3.783, "frames": 14, "iframes_frames": 17, "iframes_from_frames": 3},
	"jump": {"air": 3.067, "apex": 0.711, "frames": 23, "still_apex": 0.712, "still_frames": 23},
	"dash": {"run_half_s": 9.500, "windup_frames": 17},
	"long_jump": {"air": 6.593, "apex": 0.711, "frames": 23},
	"bounce": {"dist": 0.567, "frames": 9},
	"combo": {"hit0_dist": 0.263, "hit0_frames": 42, "hit1_dist": 0.226, "hit1_frames": 64, "hit2_dist": 0.339, "hit2_frames": 78, "spin_dist": 0.000, "spin_frames": 22},
	"hurt": {"dist": 0.844, "frames": 12},
	"counter": {"behind": 1.280, "frames": 87, "iframes_frames": 36, "move_frames": 10, "moved": 3.453},
	"plunge": {"fall_frames": 5, "hang_frames": 7, "pull_frames": 21, "rise_frames": 14, "stuck_frames": 27, "top": 1.450},
	"hook": {"dist": 7.100, "pull_frames": 16, "shot_frames": 17},
	"carry": {"lift_frames": 16, "release_frames": 9, "throw_frames": 19, "walk_half_s": 3.000},
	"items": {"bow_draw_6": 0.162, "bow_release_frames": 14, "item_get_lower_frames": 11, "item_get_show_frames": 16, "potion_frames": 48, "potion_heal_frames": 24},
	"misc": {"climb_frames": 43, "crossing_dist": 1.920, "crossing_frames": 18, "grab_presses_frames": 4},
	"push": {"block_moved": 1.905, "delay_frames": 9, "gap": 1.400, "move_frames": 21, "walked": 2.000},
}


func _level(items: Array[StringName] = [], keep_enemy := false) -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	var state := tree.root.get_node(^"GameState")
	state.reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	var enemy: Enemy = tree.current_scene.get_node(^"Enemy") as Enemy
	for other in tree.get_nodes_in_group(&"enemies"):
		if not keep_enemy or other != enemy:
			other.free()
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	for i in 300:
		if _state(player) == &"Idle":
			break
		await tree.physics_frame
	for i in items.size():
		state.give(Items.get_item(items[i]))
		state.assign_button(i, items[i])
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(60, 1, 60)
	body.add_child(shape)
	tree.current_scene.add_child(body)
	body.global_position = FAR + Vector3(0, -0.5, 0)
	await _place(tree, player, FAR, Vector3.RIGHT)
	return [tree, player, state, enemy]


func _place(tree: SceneTree, player: PlayerCharacter, at: Vector3, facing: Vector3) -> void:
	player.global_position = at
	player.velocity = Vector3.ZERO
	player.model.look_at(player.model.global_position - facing, Vector3.UP)
	for i in 10:
		await tree.physics_frame


func _box(tree: SceneTree, center: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = size
	body.add_child(shape)
	tree.current_scene.add_child(body)
	body.global_position = center
	return body


func _event(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	event.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(event)


func _tap(action: StringName) -> void:
	_event(action, true)
	_event(action, false)


func _state(player: PlayerCharacter) -> StringName:
	return player.movement_state.get_active_state().name


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(b.x - a.x, b.z - a.z).length()


## Cuadros hasta que `done` (o `limit`).
func _frames_until(tree: SceneTree, done: Callable, limit := 600) -> int:
	for i in limit:
		if done.call():
			return i
		await tree.physics_frame
	return limit


## Cuadros que dura `state` desde ahora (espera a que empiece) y lo que se movió desde el cuadro antes de empezar.
func _span(tree: SceneTree, player: PlayerCharacter, state: StringName, limit := 600) -> Dictionary:
	var from := player.global_position
	for i in 30:
		if _state(player) == state:
			break
		from = player.global_position
		await tree.physics_frame
	var top := from.y
	var frames := 0
	var takeoff := from
	var air := 0.0
	while _state(player) == state and frames < limit:
		var was_on_floor := player.is_on_floor()
		var at := player.global_position
		await tree.physics_frame
		frames += 1
		top = maxf(top, player.global_position.y)
		if was_on_floor and not player.is_on_floor():
			takeoff = at
		elif not was_on_floor and player.is_on_floor():
			air = _flat(takeoff, player.global_position)
	return {"frames": frames, "dist": _flat(from, player.global_position), "apex": top - from.y, "air": air}


func _check(name: String, measured: Dictionary) -> void:
	print("TIMING %s %s" % [name, JSON.stringify(measured)])
	if not EXPECTED.has(name):
		return
	var wanted: Dictionary = EXPECTED[name]
	for key: String in wanted:
		var tolerance: float = FRAMES if String(key).ends_with("frames") else METERS
		assert_true(absf(float(measured.get(key, INF)) - float(wanted[key])) <= tolerance + 0.0001, "%s %s: %s (antes %s)" % [name, key, measured.get(key), wanted[key]])


func _done(tree: SceneTree) -> void:
	for action in [&"move_right", &"move_left", &"move_forward", &"z-lock", &"attack", &"item_1", &"item_2", &"dodge", &"interact"]:
		_event(action, false)
		Input.action_release(action)
	TimeScale.clear()
	await tree.physics_frame
	tree.root.get_node(^"GameState").reset()


func test_walking_and_stopping() -> void:
	var setup: Array = await _level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	_event(&"move_right", true)
	var start := await _frames_until(tree, func() -> bool: return _state(player) == &"Moving")
	await tree.physics_frame
	var from := player.global_position
	for i in 60:
		await tree.physics_frame
	var walked := _flat(from, player.global_position)
	_event(&"move_right", false)
	var stop_from := player.global_position
	for i in 10:
		await tree.physics_frame
	var measured := {"start_frames": start, "walk_1s": walked, "slide": _flat(stop_from, player.global_position)}
	Input.action_press(&"z-lock")
	_event(&"z-lock", true)
	for i in 5:
		await tree.physics_frame
	from = player.global_position
	_event(&"move_right", true)
	for i in 60:
		await tree.physics_frame
	measured["guard_walk_1s"] = _flat(from, player.global_position)
	_check("walk", measured)
	await _done(tree)


func test_roll() -> void:
	var setup: Array = await _level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	_tap(&"dodge")
	var invulnerable := [0, -1]
	var count := func() -> void:
		if player.health.is_invulnerable():
			invulnerable[0] += 1
			if invulnerable[1] < 0:
				invulnerable[1] = Engine.get_physics_frames()
	tree.physics_frame.connect(count)
	var start := Engine.get_physics_frames()
	var roll := await _span(tree, player, &"Dodging")
	for i in 40:
		await tree.physics_frame
	tree.physics_frame.disconnect(count)
	roll["iframes_frames"] = invulnerable[0]
	roll["iframes_from_frames"] = invulnerable[1] - start
	roll.erase("apex")
	roll.erase("air")
	_check("roll", roll)
	await _done(tree)


func test_feather_jump() -> void:
	var setup: Array = await _level([&"feather"])
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	_tap(&"item_1")
	var still := await _span(tree, player, &"Jumping")
	for i in 10:
		await tree.physics_frame
	_event(&"move_right", true)
	for i in 20:
		await tree.physics_frame
	_tap(&"item_1")
	var moving := await _span(tree, player, &"Jumping")
	_check("jump", {"still_frames": still.frames, "still_apex": still.apex, "frames": moving.frames, "air": moving.air, "apex": moving.apex})
	await _done(tree)


func test_dash_long_jump_and_bounce() -> void:
	var setup: Array = await _level([&"feather", &"sandals"])
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var dashing := player.movement_state.get_node(^"Dashing")
	_event(&"item_2", true)
	var windup := await _frames_until(tree, func() -> bool: return _state(player) == &"Dashing" and dashing.running(), 120)
	var from := player.global_position
	for i in 30:
		await tree.physics_frame
	var run := _flat(from, player.global_position)
	_tap(&"item_1")
	var jump := await _span(tree, player, &"Jumping")
	_event(&"item_2", false)
	await _frames_until(tree, func() -> bool: return _state(player) == &"Idle", 120)
	_check("dash", {"windup_frames": windup, "run_half_s": run})
	_check("long_jump", {"frames": jump.frames, "air": jump.air, "apex": jump.apex})
	_box(tree, player.global_position + Vector3(6, 1, 0), Vector3(1, 2, 6))
	await _place(tree, player, player.global_position, Vector3.RIGHT)
	_event(&"item_2", true)
	await _frames_until(tree, func() -> bool: return _state(player) == &"Dashing" and dashing._phase == dashing.Phase.BOUNCE, 240)
	var bounce := await _span(tree, player, &"Dashing")
	_event(&"item_2", false)
	bounce.erase("apex")
	bounce.erase("air")
	_check("bounce", bounce)
	await _done(tree)


func test_combo_and_spin() -> void:
	var setup: Array = await _level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var measured := {}
	for step in 3:
		_tap(&"attack")
		var hit := await _span(tree, player, &"Attacking")
		measured["hit%d_frames" % step] = hit.frames
		measured["hit%d_dist" % step] = hit.dist
	await _frames_until(tree, func() -> bool: return _state(player) == &"Idle")
	for i in 40:
		await tree.physics_frame
	_event(&"attack", true)
	Input.action_press(&"attack")
	await _frames_until(tree, func() -> bool: return player.sword_charge.is_charged(), 180)
	Input.action_release(&"attack")
	_event(&"attack", false)
	var spin := await _span(tree, player, &"Spinning")
	measured["spin_frames"] = spin.frames
	measured["spin_dist"] = spin.dist
	_check("combo", measured)
	await _done(tree)


func test_hurt_knockback() -> void:
	var setup: Array = await _level([], true)
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var enemy: Enemy = setup[3]
	enemy.bt_player.active = false
	enemy.global_position = player.global_position - Vector3(1.5, 0, 0)
	await tree.physics_frame
	var info := enemy.config.make_damage(enemy)
	info.amount = 1
	player.hurtbox.receive(info)
	var hurt := await _span(tree, player, &"Hurt")
	hurt.erase("apex")
	hurt.erase("air")
	_check("hurt", hurt)
	await _done(tree)


func test_counter() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state := tree.root.get_node(^"GameState")
	state.reset()
	Settings.path = "user://test_player_timing_settings.cfg"
	Settings.load_settings()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	var enemy := tree.current_scene.get_node(^"Enemy") as Enemy
	for other in tree.get_nodes_in_group(&"enemies"):
		if other != enemy:
			other.free()
	state.set_flag(Counter.LEARNED, true)
	use_gamepad()
	await tree.physics_frame
	enemy.bt_player.active = false
	enemy.health.max_health = 400
	enemy.health.current = 400
	enemy.global_position = player.global_position + Vector3(0, 0, 2.2)
	var to_player := player.global_position - enemy.global_position
	enemy.look_at(enemy.global_position - to_player, Vector3.UP)
	enemy.model.rotation = Vector3.ZERO
	for i in 3:
		await tree.physics_frame
	var lock := player.controls.action(&"z-lock")
	_event(lock, true)
	Input.action_press(lock)
	await _frames_until(tree, func() -> bool: return player.targeting.current == enemy, 30)
	enemy.telegraph(1.0)
	await _frames_until(tree, func() -> bool: return player.counter.is_open(), 240)
	var attack := player.controls.action(&"attack")
	_tap(attack)
	await _frames_until(tree, func() -> bool: return _state(player) == &"Countering", 10)
	var from := player.global_position
	var invulnerable := [0]
	var count := func() -> void:
		if player.health.is_invulnerable():
			invulnerable[0] += 1
	tree.physics_frame.connect(count)
	var move := await _frames_until(tree, func() -> bool: return player.attack_runner.is_running(), 60)
	var moved := _flat(from, player.global_position)
	var behind := _flat(enemy.global_position, player.global_position)
	var rest := await _frames_until(tree, func() -> bool: return _state(player) != &"Countering", 120)
	for i in 30:
		await tree.physics_frame
	tree.physics_frame.disconnect(count)
	Input.action_release(lock)
	_event(lock, false)
	_check("counter", {"move_frames": move, "moved": moved, "behind": behind, "frames": move + rest, "iframes_frames": invulnerable[0]})
	DirAccess.remove_absolute(Settings.path)
	Settings.path = Settings.PATH
	Settings.load_settings()
	await _done(tree)


func test_plunge() -> void:
	var setup: Array = await _level([&"feather"])
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var state: Node = setup[2]
	state.set_flag(Plunging.LEARNED, true)
	var plunging := player.movement_state.get_node(^"Plunging") as Plunging
	var jumping := player.movement_state.get_node(^"Jumping")
	var floor_y := player.global_position.y
	_tap(&"item_1")
	await _frames_until(tree, func() -> bool: return _state(player) == &"Jumping" and jumping.airborne_height() > 0.3, 60)
	_tap(&"attack")
	await _frames_until(tree, func() -> bool: return _state(player) == &"Plunging", 10)
	var frames := {}
	var top := 0.0
	var phase := plunging.phase
	var count := 0
	while _state(player) == &"Plunging" and count < 600:
		await tree.physics_frame
		count += 1
		top = maxf(top, player.global_position.y - floor_y)
		var name: String = Plunging.Phase.keys()[phase].to_lower() + "_frames"
		frames[name] = frames.get(name, 0) + 1
		if _state(player) == &"Plunging":
			phase = plunging.phase
	frames["top"] = top
	_check("plunge", frames)
	await _done(tree)


func test_hookshot_pull() -> void:
	var setup: Array = await _level([&"hookshot"])
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var post := POST.instantiate() as Node3D
	tree.current_scene.add_child(post)
	post.global_position = player.global_position + Vector3(8, 0, 0)
	await _place(tree, player, player.global_position, Vector3.RIGHT)
	tree.call_group(TopDownCamera.GROUP, &"snap_to_target")
	var hooking := player.movement_state.get_node(^"Hooking")
	var from := player.global_position
	_tap(&"item_1")
	await _frames_until(tree, func() -> bool: return _state(player) == &"Hooking", 10)
	var shot := await _frames_until(tree, func() -> bool: return hooking.pulling(), 120)
	var pull := await _frames_until(tree, func() -> bool: return not hooking.pulling(), 120)
	_check("hook", {"shot_frames": shot, "pull_frames": pull, "dist": _flat(from, player.global_position)})
	await _done(tree)


func test_carry_and_throw() -> void:
	var setup: Array = await _level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var pot := tree.current_scene.get_node(^"Pot1") as Node3D
	await _place(tree, player, pot.global_position + Vector3(0, 0, 1.0), Vector3.FORWARD)
	_tap(&"interact")
	await _frames_until(tree, func() -> bool: return _state(player) == &"Carrying", 10)
	var from := player.global_position
	_event(&"move_right", true)
	var lift := await _frames_until(tree, func() -> bool: return _flat(from, player.global_position) > 0.01, 120)
	from = player.global_position
	for i in 30:
		await tree.physics_frame
	var walked := _flat(from, player.global_position)
	_event(&"move_right", false)
	for i in 5:
		await tree.physics_frame
	_tap(&"interact")
	await tree.physics_frame
	var release := await _frames_until(tree, func() -> bool: return not player.carrier.is_carrying(), 120)
	var rest := await _frames_until(tree, func() -> bool: return _state(player) == &"Idle", 120)
	_check("carry", {"lift_frames": lift, "walk_half_s": walked, "release_frames": release, "throw_frames": release + rest})
	await _done(tree)


func test_potion_bow_and_item_get() -> void:
	var setup: Array = await _level([&"bow"])
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var state: Node = setup[2]
	state.give(Items.get_item(&"arrow"), 10)
	state.give(Items.get_item(&"potion"))
	state.assign_button(1, &"bottle_1")
	player.health.invulnerability_time = 0.0
	player.health.damage(4)
	var hurt := player.health.current
	_tap(&"item_2")
	await _frames_until(tree, func() -> bool: return _state(player) == &"UsingItem", 10)
	var healed := [-1]
	var frames := 0
	while _state(player) == &"UsingItem" and frames < 300:
		await tree.physics_frame
		frames += 1
		if healed[0] < 0 and player.health.current > hurt:
			healed[0] = frames
	var measured := {"potion_frames": frames, "potion_heal_frames": healed[0]}
	for i in 20:
		await tree.physics_frame
	_event(&"item_1", true)
	await _frames_until(tree, func() -> bool: return _state(player) == &"AimingItem", 10)
	for i in 6:
		await tree.physics_frame
	var bow = player.equipment.held
	measured["bow_draw_6"] = bow.draw if is_instance_valid(bow) else -1.0
	for i in 34:
		await tree.physics_frame
	_event(&"item_1", false)
	measured["bow_release_frames"] = await _frames_until(tree, func() -> bool: return _state(player) != &"AimingItem", 120)
	for i in 20:
		await tree.physics_frame
	state.set_flag(&"tut_bow_shown", true)
	var stack: Node = tree.root.get_node(^"MenuStack")
	player.play_item_get(Items.get_item(&"bow"))
	measured["item_get_show_frames"] = await _frames_until(tree, func() -> bool: return stack.top() != null and stack.top().has_signal(&"closed"), 240)
	stack.pop()
	measured["item_get_lower_frames"] = await _frames_until(tree, func() -> bool: return _state(player) == &"Idle", 240)
	_check("items", measured)
	await _done(tree)


func test_room_crossing_grab_and_climb() -> void:
	var setup: Array = await _level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	player.begin_room_transition(Vector3.RIGHT, 0.6)
	var crossing := await _span(tree, player, &"Transition")
	var grip := Node3D.new()
	tree.current_scene.add_child(grip)
	grip.global_position = player.global_position + Vector3(0, 0.5, 0)
	player.grab(grip)
	var presses := 0
	while _state(player) == &"Grabbed" and presses < 40:
		_tap(&"attack")
		presses += 1
		for i in 3:
			await tree.physics_frame
	grip.free()
	player.input_buffer.clear()
	for i in 90:
		await tree.physics_frame
	await _frames_until(tree, func() -> bool: return _state(player) == &"Idle", 60)
	var at := player.global_position
	player.climb(PackedVector3Array([at + Vector3(0.5, 0, 0), at + Vector3(0.5, 2, 0), at + Vector3(1.5, 2, 0)]), Vector3.RIGHT)
	var climb := await _span(tree, player, &"Climbing")
	_check("misc", {"crossing_frames": crossing.frames, "crossing_dist": crossing.dist, "grab_presses_frames": presses, "climb_frames": climb.frames})
	await _done(tree)


func test_block_push() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	state.reset()
	tree.change_scene_to_file("res://levels/test/test_rooms.tscn")
	await tree.scene_changed
	for i in 3:
		await tree.physics_frame
	tree.current_scene.get_node(^"Skeleton").free()
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	var block: PushBlock = tree.current_scene.get_node(^"Block")
	player.global_position = Vector3(-6, 0.25, -13.6)
	for i in 30:
		await tree.physics_frame
	var from := player.global_position
	_event(&"move_forward", true)
	await _frames_until(tree, func() -> bool: return _state(player) == &"Pushing", 120)
	var delay := await _frames_until(tree, func() -> bool: return block.moving, 120)
	var start := block.global_position
	var move := await _frames_until(tree, func() -> bool: return not block.moving, 120)
	var gap := _flat(player.global_position, block.global_position)
	_event(&"move_forward", false)
	_check("push", {"delay_frames": delay, "move_frames": move, "block_moved": _flat(start, block.global_position), "gap": gap, "walked": _flat(from, player.global_position)})
	await _done(tree)
