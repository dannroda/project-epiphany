extends "res://tests/test_case.gd"
## Salas del templo (M8), una prueba por tarea.

const LEVEL := "res://levels/temple.tscn"

var tree: SceneTree
var state: Node
var level: Node
var player: PlayerCharacter


func _start(items := []) -> void:
	tree = Engine.get_main_loop() as SceneTree
	state = tree.root.get_node(^"GameState")
	state.reset()
	for entry in items:
		state.give(Items.get_item(entry[0]), entry[1])
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	await tree.create_timer(0.3).timeout
	level = tree.current_scene
	player = tree.get_first_node_in_group(&"player") as PlayerCharacter
	player.health.invulnerability_time = 0.0


func _scenario(scenario: String) -> void:
	tree = Engine.get_main_loop() as SceneTree
	state = tree.root.get_node(^"GameState")
	state.reset()
	assert_eq(await tree.root.get_node(^"SaveManager").load_scenario(scenario), OK)
	level = tree.current_scene
	player = tree.get_first_node_in_group(&"player") as PlayerCharacter
	while player.movement_state.get_active_state().name == &"Spawning":
		await tree.physics_frame
	await tree.create_timer(0.2).timeout
	player.health.invulnerability_time = 0.0


func _face(direction: Vector3) -> void:
	player.look_at(player.global_position + direction.normalized(), Vector3.UP)
	player.model.rotation = Vector3(0, PI, 0)


func _press(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	var release := InputEventAction.new()
	release.action = action
	Input.parse_input_event(release)
	for i in 3:
		await tree.physics_frame


func _block(on: bool) -> void:
	if on:
		use_gamepad()
	hold_block(player, on)


func _open_chest(chest_name: NodePath) -> void:
	var stack: Node = tree.root.get_node(^"MenuStack")
	(level.get_node(chest_name) as Chest).interactable.interact(player)
	await tree.create_timer(1.0).timeout
	while stack.is_open():
		stack.pop()
	await tree.create_timer(1.2).timeout


func _bomb_at(stand: Vector3, facing: Vector3, retreat: Vector3) -> void:
	player.global_position = stand
	_face(facing)
	await tree.physics_frame
	await _press(&"item_1")
	await tree.create_timer(1.0).timeout
	player.global_position = retreat
	await tree.create_timer(2.6).timeout


func _walk(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	event.strength = 1.0
	Input.parse_input_event(event)


func _walk_until(action: StringName, done: Callable) -> bool:
	_walk(action, true)
	var until := Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < until and not done.call():
		await tree.physics_frame
	_walk(action, false)
	await tree.physics_frame
	return done.call()


func _push(block_name: NodePath, directions: Array) -> void:
	var block := level.get_node(block_name) as PushBlock
	for direction in directions:
		assert_true(block.try_push(direction), "%s avanza hacia %s" % [block_name, direction])
		await tree.create_timer(0.6).timeout
	var camera := level.get_node(^"TopDownCamera") as TopDownCamera
	while camera.revealing:
		await tree.process_frame


func _kill(names: Array) -> void:
	for enemy_name in names:
		var enemy := level.get_node(enemy_name) as Enemy
		enemy.health.invulnerability_time = 0.0
		enemy.health.damage(100)


func _door(door_name: NodePath) -> Door:
	return level.get_node(door_name) as Door


func test_rooms_1_2_vestibule_to_the_hub() -> void:
	await _start()
	var camera := level.get_node(^"TopDownCamera") as TopDownCamera
	assert_eq(state.current_dungeon, &"d1", "templo = mazmorra 1")
	assert_eq(camera.room, level.get_node(^"Vestibulo"), "arranca en el vestíbulo")
	assert_eq(_door(^"VestibuleDoor").is_open, false, "la puerta al hub espera el interruptor")
	player.global_position = Vector3(16, 0, 60)
	await _push(^"VestibuleBlock", [Vector3.RIGHT, Vector3.RIGHT, Vector3.RIGHT, Vector3.RIGHT, Vector3.FORWARD, Vector3.FORWARD])
	await tree.create_timer(0.8).timeout
	assert_eq(_door(^"VestibuleDoor").is_open, true, "el bloque en el interruptor abre la puerta")

	player.global_position = Vector3(24, 0, 59)
	assert_true(await _walk_until(&"move_forward", func() -> bool: return player.global_position.z <= 52.0), "camina hasta el hub")
	await tree.create_timer(1.0).timeout
	assert_eq(camera.room, level.get_node(^"Hub"), "entra al hub")
	assert_eq(_door(^"VestibuleDoor").is_open, true, "sur: libre")
	assert_eq(_door(^"HubShutterW").is_open, false, "oeste: persiana cerrada con los esqueletos")
	assert_eq(_door(^"HubLockedE").is_open, false, "este: con llave")
	assert_eq(_door(^"HubLockedE").kind, Door.Kind.LOCKED)
	assert_eq(_door(^"HubSeal").is_open, false, "norte: el sello, cerrado")
	_kill([^"HubSkeleton1", ^"HubSkeleton2"])
	await tree.create_timer(0.8).timeout
	assert_eq(_door(^"HubShutterW").is_open, true, "sin esqueletos se abre la persiana")
	state.reset()


func test_rooms_3_4_key_and_map_without_the_bow() -> void:
	await _scenario("dungeon_no_bow")
	assert_eq(state.inventory.has(&"bow"), false, "dungeon_no_bow: sin arco")
	_kill([^"HubSkeleton1", ^"HubSkeleton2"])

	var pad := InputEventJoypadMotion.new()
	pad.axis = JOY_AXIS_RIGHT_X
	pad.axis_value = 0.3
	Input.parse_input_event(pad)
	var still := InputEventJoypadMotion.new()
	still.axis = JOY_AXIS_RIGHT_X
	still.axis_value = 0.0
	Input.parse_input_event(still)
	player.global_position = Vector3(0, 0, 50)
	await tree.create_timer(1.0).timeout
	player.global_position = Vector3(0, 0, 50)
	_face(Vector3(-1, 0, -1))
	_block(true)
	var eye := level.get_node(^"GalleryEye") as EyeSwitch
	var until := Time.get_ticks_msec() + 9000
	while Time.get_ticks_msec() < until and not eye.active:
		await tree.physics_frame
	_block(false)
	assert_eq(eye.active, true, "el orbe de la torreta, reflejado con el espejo, despierta el ojo")
	assert_true(eye.gem.visible and eye.glow.visible, "la torre se ilumina arriba, visible desde la cámara")
	await tree.create_timer(0.8).timeout
	assert_eq((level.get_node(^"GalleryKeyGate") as Gate).is_open, true, "y baja la reja del nicho")
	level.get_node(^"GalleryTurret").free()
	player.global_position = Vector3(-8, 0, 52.6)
	_face(Vector3.BACK)
	await _open_chest(^"GalleryKeyChest")
	assert_eq(state.current_dungeon_state().small_keys, 1, "llave 1")
	assert_eq(_door(^"OjosDoor").is_open, false, "la puerta norte de la galería espera una flecha")

	player.global_position = Vector3(34, 0, 48)
	_door(^"HubLockedE").interactable.interact(player)
	assert_eq(_door(^"HubLockedE").is_open, true, "la llave abre el este del hub")
	await tree.create_timer(0.8).timeout
	player.global_position = Vector3(48, 0, 52)
	await tree.create_timer(1.0).timeout
	var box := level.get_node(^"CrackedBox") as Node3D
	await _bomb_at(Vector3(48, 0, 48.6), Vector3.FORWARD, Vector3(48, 0, 54))
	assert_true(box.global_position.distance_to(Vector3(48, 0.5, 46)) > 1.2, "la bomba vuela la caja del hueco (%s)" % box.global_position)
	player.global_position = Vector3(48, 0, 50)
	assert_true(await _walk_until(&"move_forward", func() -> bool: return player.global_position.z <= 44.0), "pasa por el hueco (player %s, caja %s)" % [player.global_position.snappedf(0.1), box.global_position.snappedf(0.1)])
	player.global_position = Vector3(54, 0, 43.4)
	_face(Vector3.FORWARD)
	await _open_chest(^"MapChest")
	assert_eq(state.current_dungeon_state().has_map, true, "el mapa")
	await _bomb_at(Vector3(48, 0, 41.4), Vector3.FORWARD, Vector3(52, 0, 44))
	assert_eq((level.get_node(^"ArenaCrackedWall") as CrackedWall).is_broken, true, "el muro hacia la arena")
	state.reset()



func _alive_in(room_name: NodePath) -> Array:
	return (level.get_node(room_name) as Room).enemies_inside()


func _kill_all(enemies: Array) -> void:
	for enemy: Enemy in enemies:
		enemy.health.invulnerability_time = 0.0
		enemy.health.damage(100)


func _enter_arena() -> WaveSpawner:
	_kill([^"HubSkeleton1", ^"HubSkeleton2"])
	player.global_position = Vector3(48, 0, 37)
	await tree.create_timer(1.5).timeout
	return level.get_node(^"ArenaWaves") as WaveSpawner


func test_room_5_arena_waves_and_the_bow() -> void:
	await _scenario("dungeon_no_bow")
	var waves := await _enter_arena()
	assert_eq(waves.running, true, "las oleadas empiezan al entrar")
	assert_eq(_door(^"ArenaShutter").is_open, false, "la persiana encierra al player")
	assert_eq(_alive_in(^"Arena").size(), 2, "primera oleada: dos esqueletos")
	_kill_all(_alive_in(^"Arena"))
	await tree.create_timer(0.5).timeout
	assert_eq(_door(^"ArenaShutter").is_open, false, "entre oleadas sigue cerrada")
	await tree.create_timer(1.0).timeout
	var second := _alive_in(^"Arena")
	assert_eq(second.size(), 3, "segunda oleada")
	assert_true(second.any(func(enemy: Enemy) -> bool: return enemy.config.guards_front), "con el esqueleto con escudo")
	_kill_all(second)
	await tree.create_timer(1.0).timeout
	assert_eq(waves.active, true, "ganadas")
	assert_eq(_door(^"ArenaShutter").is_open, true, "se abre la persiana")
	assert_eq((level.get_node(^"BowGate") as Gate).is_open, true, "y la reja del cofre")
	player.global_position = Vector3(48, 0, 28)
	_face(Vector3.FORWARD)
	await _open_chest(^"BowChest")
	assert_eq(state.inventory.has(&"bow"), true, "el arco")
	assert_eq(state.inventory.count(&"arrow"), 10, "con flechas iniciales")
	assert_eq(state.get_flag(&"d1_chest_bow"), true)
	state.reset()


func test_dying_mid_wave_restarts_the_arena() -> void:
	await _scenario("dungeon_no_bow")
	var waves := await _enter_arena()
	_kill_all(_alive_in(^"Arena"))
	await tree.create_timer(1.5).timeout
	assert_eq(waves.wave, 1, "va por la segunda oleada")
	await tree.root.get_node(^"SceneFlow").respawn()
	level = tree.current_scene
	await tree.create_timer(1.0).timeout
	waves = level.get_node(^"ArenaWaves") as WaveSpawner
	assert_eq(waves.running, true, "al reaparecer en la arena vuelve a empezar")
	assert_eq(waves.wave, 0, "desde la primera oleada")
	assert_eq(_alive_in(^"Arena").size(), 2)
	assert_true(state.get_flag(&"d1_arena_cleared") != true, "sin ganar")
	state.reset()


func _shoot(from: Vector3, eye_name: NodePath) -> void:
	var eye := level.get_node(eye_name) as EyeSwitch
	var arrow: Projectile = load("res://src/items/arrow/arrow.tscn").instantiate()
	level.add_child(arrow)
	var info := Items.get_item(&"bow").make_damage(player)
	info.team = EntityConfig.Team.PLAYER
	arrow.launch(from, (eye.eye.global_position - from).normalized() * 20.0, info)
	await tree.create_timer(1.0).timeout


func _reflect_beam(at: Vector3, facing: Vector3) -> void:
	player.global_position = at
	_face(facing)
	_block(true)
	for i in 8:
		await tree.physics_frame
	_block(false)
	await tree.create_timer(0.8).timeout


func test_rooms_6_7_with_the_bow() -> void:
	await _scenario("dungeon_no_bow")
	state.give(Items.get_item(&"bow"))
	_kill([^"HubSkeleton1", ^"HubSkeleton2"])
	player.global_position = Vector3(0, 0, 36)
	await tree.create_timer(1.2).timeout
	assert_eq((level.get_node(^"TopDownCamera") as TopDownCamera).room, level.get_node(^"Ojos"), "en la sala de ojos")

	await _shoot(Vector3(-8, 1.2, 34), ^"OjosEyeA")
	assert_eq((level.get_node(^"OjosCompassGate") as Gate).is_open, true, "una flecha al ojo oeste abre el nicho")
	player.global_position = Vector3(-8, 0, 35)
	_face(Vector3.BACK)
	await _open_chest(^"OjosCompassChest")
	assert_eq(state.current_dungeon_state().has_compass, true, "la brújula")

	var hp: int = player.health.current
	player.global_position = Vector3(4, 0.2, 31)
	await tree.create_timer(1.5).timeout
	assert_true(player.health.current < hp, "caer al hueco lastima")
	assert_true(player.global_position.z > 33.0 and player.global_position.y > -0.5, "y devuelve a la entrada (%s)" % player.global_position)

	await _shoot(Vector3(8, 1.2, 34), ^"OjosEyeB")
	assert_eq((level.get_node(^"OjosBridge") as Bridge).is_up, true, "el ojo este sube el puente")
	await tree.create_timer(1.0).timeout
	player.global_position = Vector3(0, 0, 35)
	assert_true(await _walk_until(&"move_forward", func() -> bool: return player.global_position.z <= 27.5), "cruza el puente")
	assert_true(player.global_position.y > -0.3, "sin caerse")
	player.global_position = Vector3(-4, 0, 27.4)
	_face(Vector3.FORWARD)
	await _open_chest(^"OjosKeyChest")
	assert_eq(state.current_dungeon_state().small_keys, 1, "llave 2")
	_door(^"PuzzleDoor").interactable.interact(player)
	assert_eq(_door(^"PuzzleDoor").is_open, true, "abre la puerta al puzzle")

	player.global_position = Vector3(6, 0, 16)
	await tree.create_timer(1.2).timeout
	await _push(^"PuzzleBlock", [Vector3.LEFT, Vector3.LEFT])
	await tree.create_timer(0.8).timeout
	assert_eq((level.get_node(^"PuzzleBeamGate") as Gate).is_open, true, "1) el bloque baja la reja que cortaba el haz")
	await _reflect_beam(Vector3(4, 0, 14), Vector3(-1, 0, -1))
	assert_eq((level.get_node(^"PuzzleCrystal") as LightReceiver).lit, true, "2) el espejo lleva el haz al cristal")
	assert_eq((level.get_node(^"PuzzleEyeGate") as Gate).is_open, true, "que descubre el ojo")
	await _shoot(Vector3(4, 1.2, 12), ^"PuzzleEye")
	assert_eq((level.get_node(^"BossKeyGate") as Gate).is_open, true, "3) la flecha al ojo abre el nicho de la llave del jefe")
	assert_eq(_door(^"HubSeal").is_open, true, "y el sello del hub")
	player.global_position = Vector3(0, 0, 12.4)
	_face(Vector3.FORWARD)
	await _open_chest(^"BossKeyChest")
	assert_eq(state.current_dungeon_state().has_boss_key, true, "la llave del jefe")
	state.reset()


func test_room_8_boss_door_and_checkpoint() -> void:
	await _scenario("pre_boss")
	var camera := level.get_node(^"TopDownCamera") as TopDownCamera
	assert_eq(camera.room, level.get_node(^"Antesala"), "pre_boss arranca en la antesala")
	assert_eq(state.current_dungeon_state().has_boss_key, true)
	var door := _door(^"BossDoor")
	door.interactable.interact(player)
	assert_eq(door.is_open, true, "la llave del jefe abre su puerta")
	assert_eq(state.current_dungeon_state().has_boss_key, true, "sin gastarla")
	await tree.create_timer(0.8).timeout
	player.global_position = Vector3(24, 0, 21)
	await tree.create_timer(1.2).timeout
	assert_eq(camera.room, level.get_node(^"Jefe"), "entra a la guarida")
	player.health.damage(100)
	var stack: Node = tree.root.get_node(^"MenuStack")
	for i in 400:
		if stack.top() is GameOver:
			break
		await tree.process_frame
	assert_true(stack.top() is GameOver, "game over")
	(stack.top() as GameOver)._continue.pressed.emit()
	var until := Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < until and (tree.current_scene == level or tree.get_first_node_in_group(&"player") == null or (tree.get_first_node_in_group(&"player") as PlayerCharacter).is_dead):
		await tree.process_frame
	await tree.create_timer(1.0).timeout
	level = tree.current_scene
	player = tree.get_first_node_in_group(&"player") as PlayerCharacter
	camera = level.get_node(^"TopDownCamera") as TopDownCamera
	assert_eq(camera.room, level.get_node(^"Antesala"), "morir contra el jefe devuelve a la antesala")
	assert_eq(_door(^"BossDoor").is_open, true, "con la puerta del jefe abierta")
	state.reset()


func test_loading_past_the_eye_keeps_its_doors_open() -> void:
	await _scenario("pre_boss")
	assert_eq(_door(^"HubSeal").is_open, true, "el sello del hub sigue abierto aunque su ojo esté después en la escena")
	assert_eq((level.get_node(^"BossKeyGate") as Gate).is_open, true, "y la reja de la llave del jefe")
	state.reset()


func test_room_8_boss_door_needs_its_key() -> void:
	await _scenario("pre_boss")
	state.current_dungeon_state().has_boss_key = false
	_door(^"BossDoor").interactable.interact(player)
	assert_eq(_door(^"BossDoor").is_open, false, "sin la llave del jefe no abre")
	var stack: Node = tree.root.get_node(^"MenuStack")
	while stack.is_open():
		stack.pop()
	state.reset()


func _lap(laps: Array, label: String) -> void:
	laps.append([label, Time.get_ticks_msec()])


func test_full_run_from_the_entrance_to_the_boss_door() -> void:
	await _start([[&"shield_mirror", 1], [&"bomb_bag", 1]])
	state.equip(Items.get_item(&"shield_mirror"))
	var laps := [["inicio", Time.get_ticks_msec()]]

	player.global_position = Vector3(16, 0, 60)
	await _push(^"VestibuleBlock", [Vector3.RIGHT, Vector3.RIGHT, Vector3.RIGHT, Vector3.RIGHT, Vector3.FORWARD, Vector3.FORWARD])
	await tree.create_timer(0.8).timeout
	player.global_position = Vector3(24, 0, 59)
	assert_true(await _walk_until(&"move_forward", func() -> bool: return player.global_position.z <= 52.0), "vestíbulo → hub")
	_kill([^"HubSkeleton1", ^"HubSkeleton2"])
	await tree.create_timer(0.8).timeout
	_lap(laps, "vestíbulo y hub")

	var pad := InputEventJoypadMotion.new()
	pad.axis = JOY_AXIS_RIGHT_X
	Input.parse_input_event(pad)
	player.global_position = Vector3(0, 0, 50)
	await tree.create_timer(1.0).timeout
	player.global_position = Vector3(0, 0, 50)
	_face(Vector3(-1, 0, -1))
	_block(true)
	var eye := level.get_node(^"GalleryEye") as EyeSwitch
	var until := Time.get_ticks_msec() + 9000
	while Time.get_ticks_msec() < until and not eye.active:
		await tree.physics_frame
	_block(false)
	level.get_node(^"GalleryTurret").free()
	await tree.create_timer(0.8).timeout
	player.global_position = Vector3(-8, 0, 52.6)
	_face(Vector3.BACK)
	await _open_chest(^"GalleryKeyChest")
	assert_eq(state.current_dungeon_state().small_keys, 1, "galería: llave 1")
	_lap(laps, "galería")

	player.global_position = Vector3(34, 0, 48)
	_door(^"HubLockedE").interactable.interact(player)
	await tree.create_timer(0.8).timeout
	player.global_position = Vector3(48, 0, 52)
	await tree.create_timer(1.0).timeout
	await _bomb_at(Vector3(48, 0, 48.6), Vector3.FORWARD, Vector3(48, 0, 54))
	player.global_position = Vector3(48, 0, 50)
	assert_true(await _walk_until(&"move_forward", func() -> bool: return player.global_position.z <= 44.0), "agrietada: pasa el hueco")
	player.global_position = Vector3(54, 0, 43.4)
	_face(Vector3.FORWARD)
	await _open_chest(^"MapChest")
	await _bomb_at(Vector3(48, 0, 41.4), Vector3.FORWARD, Vector3(52, 0, 44))
	assert_eq(state.current_dungeon_state().has_map, true, "agrietada: mapa")
	_lap(laps, "sala agrietada")

	player.global_position = Vector3(48, 0, 37)
	await tree.create_timer(1.5).timeout
	for i in 2:
		_kill_all(_alive_in(^"Arena"))
		await tree.create_timer(1.5).timeout
	player.global_position = Vector3(48, 0, 28)
	_face(Vector3.FORWARD)
	await _open_chest(^"BowChest")
	assert_eq(state.inventory.has(&"bow"), true, "arena: arco")
	_lap(laps, "arena")

	player.global_position = Vector3(2, 0, 46)
	await tree.create_timer(1.2).timeout
	await _shoot(Vector3(2, 1.2, 46), ^"OjosDoorEye")
	assert_eq(_door(^"OjosDoor").is_open, true, "con el arco se abre el norte de la galería")
	player.global_position = Vector3(0, 0, 36)
	await tree.create_timer(1.2).timeout
	await _shoot(Vector3(-8, 1.2, 34), ^"OjosEyeA")
	player.global_position = Vector3(-8, 0, 35)
	_face(Vector3.BACK)
	await _open_chest(^"OjosCompassChest")
	await _shoot(Vector3(8, 1.2, 34), ^"OjosEyeB")
	await tree.create_timer(1.0).timeout
	player.global_position = Vector3(0, 0, 35)
	assert_true(await _walk_until(&"move_forward", func() -> bool: return player.global_position.z <= 27.5), "ojos: cruza el puente")
	player.global_position = Vector3(-4, 0, 27.4)
	_face(Vector3.FORWARD)
	await _open_chest(^"OjosKeyChest")
	_door(^"PuzzleDoor").interactable.interact(player)
	assert_eq(state.current_dungeon_state().has_compass, true, "ojos: brújula")
	_lap(laps, "sala de ojos")

	player.global_position = Vector3(0, 0, 22.2)
	await tree.create_timer(1.2).timeout
	player.global_position = Vector3(0, 0, 21.0)
	assert_true(await _walk_until(&"move_forward", func() -> bool: return player.global_position.z <= 17.0), "puzzle: la entrada se camina, sin pluma")
	assert_true(player.global_position.y > -0.1, "y sin huecos")
	player.global_position = Vector3(6, 0, 16)
	await tree.physics_frame
	await _push(^"PuzzleBlock", [Vector3.LEFT, Vector3.LEFT])
	await tree.create_timer(0.8).timeout
	await _reflect_beam(Vector3(4, 0, 14), Vector3(-1, 0, -1))
	await _shoot(Vector3(4, 1.2, 12), ^"PuzzleEye")
	player.global_position = Vector3(0, 0, 12.4)
	_face(Vector3.FORWARD)
	await _open_chest(^"BossKeyChest")
	assert_eq(state.current_dungeon_state().has_boss_key, true, "puzzle: llave del jefe")
	_lap(laps, "puzzle")

	player.global_position = Vector3(24, 0, 44)
	await tree.create_timer(1.2).timeout
	assert_true(await _walk_until(&"move_forward", func() -> bool: return player.global_position.z <= 36.0), "por el sello del hub a la antesala")
	await tree.create_timer(0.8).timeout
	_door(^"BossDoor").interactable.interact(player)
	assert_eq(_door(^"BossDoor").is_open, true, "la puerta del jefe")
	_lap(laps, "antesala")
	for n in range(1, laps.size()):
		print("  recorrido · %s: %.1f s" % [laps[n][0], (laps[n][1] - laps[n - 1][1]) / 1000.0])
	state.reset()


func test_south_wall_cut_covers_the_brick_relief() -> void:
	await _start()
	var camera := level.get_node(^"TopDownCamera") as TopDownCamera
	var kit: MeshLibrary = (level.find_children("*", "GridMap", true, false)[0] as GridMap).mesh_library
	var stone: ShaderMaterial = load("res://data/kits/materials/epiphany_stone.tres")
	var cut: Vector4 = stone.get_shader_parameter(&"cut_area")
	var room_end := camera.room.bounds().end.y
	for id in [1, 15, 16]:
		var relief := -kit.get_item_mesh(id).get_aabb().position.z - 1.0
		assert_true(cut.z < room_end - relief, "el corte empieza antes que los ladrillos de %s (sobresalen %.2f m)" % [kit.get_item_name(id), relief])
	state.reset()


func test_doorways_face_their_wall() -> void:
	var temple: Node = load(LEVEL).instantiate()
	var grid := temple.get_node(^"GridMap") as GridMap
	var walls := [1, 15, 16]
	var side := grid.get_orthogonal_index_from_basis(Basis(Vector3.UP, PI / 2.0))
	for cell in grid.get_used_cells_by_item(4):
		var in_side_wall: bool = grid.get_cell_item(cell + Vector3i(0, 0, -1)) in walls and grid.get_cell_item(cell + Vector3i(0, 0, 1)) in walls
		var expected := side if in_side_wall else 0
		assert_eq(grid.get_cell_item_orientation(cell), expected, "el marco de la puerta %s sigue a su pared" % cell)
	temple.free()
