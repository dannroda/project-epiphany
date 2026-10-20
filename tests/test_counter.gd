extends "res://tests/test_case.gd"
## 11.34 paso 3: contraataque. Con un enemigo fijado, en los últimos 0,35 s de su aviso atacar lo esquiva y le pega
## por la espalda (×2, aturde); el mundo va a media velocidad mientras dura la ventana, salvo con la opción apagada.

const LEVEL := "res://levels/test.tscn"
const SHIELD_SKELETON := "res://src/entities/shield_skeleton.tscn"


func _level(learned := true, scene := "") -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	var state := tree.root.get_node(^"GameState")
	state.reset()
	Settings.path = "user://test_counter_settings.cfg"
	Settings.load_settings()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	var level := tree.current_scene
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	var enemy := level.get_node(^"Enemy") as Enemy
	for other in tree.get_nodes_in_group(&"enemies"):
		if other != enemy:
			other.free()
	if scene != "":
		var swap := (load(scene) as PackedScene).instantiate() as Enemy
		level.add_child(swap)
		enemy.free()
		enemy = swap
	if learned:
		state.set_flag(Counter.LEARNED, true)
	use_gamepad()
	await tree.physics_frame
	enemy.bt_player.active = false
	enemy.global_position = player.global_position + Vector3(0, 0, 2.2)
	var to_player := player.global_position - enemy.global_position
	enemy.look_at(enemy.global_position - to_player, Vector3.UP)
	enemy.model.rotation = Vector3.ZERO
	for i in 3:
		await tree.physics_frame
	var lock := InputEventAction.new()
	lock.action = player.controls.action(&"z-lock")
	lock.pressed = true
	Input.parse_input_event(lock)
	Input.action_press(lock.action)
	await _until(tree, func() -> bool: return player.targeting.current == enemy, 30)
	return [tree, player, enemy]


func _done(tree: SceneTree, player: PlayerCharacter) -> void:
	for action in [&"attack", &"z-lock", &"dodge"]:
		Input.action_release(player.controls.action(action))
	TimeScale.clear()
	await tree.physics_frame
	DirAccess.remove_absolute(Settings.path)
	Settings.path = Settings.PATH
	Settings.load_settings()
	tree.root.get_node(^"GameState").reset()


func _tap(player: PlayerCharacter, action: StringName) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = player.controls.action(action)
		event.pressed = pressed
		Input.parse_input_event(event)


func _state(player: PlayerCharacter) -> StringName:
	return player.movement_state.get_active_state().name


func _until(tree: SceneTree, done: Callable, frames := 240) -> bool:
	for i in frames:
		if done.call():
			return true
		await tree.physics_frame
	return done.call()


func _behind(player: PlayerCharacter, enemy: Enemy) -> bool:
	var away := (player.global_position - enemy.global_position) * Vector3(1, 0, 1)
	return away.normalized().dot(enemy.facing()) < -0.3


func test_the_window_opens_only_at_the_end_of_the_telegraph() -> void:
	var setup: Array = await _level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var enemy: Enemy = setup[2]
	assert_eq(player.targeting.current, enemy, "fijado")
	enemy.telegraph(1.0)
	await tree.physics_frame
	assert_true(not player.counter.is_open(), "al empezar el aviso, todavía no")
	assert_true(await _until(tree, func() -> bool: return player.counter.is_open()), "se abre al final del aviso")
	assert_true(enemy.strike_in() <= player.counter.window + 0.02, "en los últimos %.2f s" % player.counter.window)
	assert_true(is_equal_approx(Engine.time_scale, player.counter.slow_scale), "el mundo a media velocidad")
	assert_true(player.counter.prompt.visible and player.counter.prompt.texture != null, "con el botón sobre el enemigo")
	assert_eq(player.counter.glint.current_animation, &"glint", "y la espada destella")
	enemy.end_telegraph()
	await tree.physics_frame
	await tree.physics_frame
	assert_true(not player.counter.is_open() and is_equal_approx(Engine.time_scale, 1.0), "pasado el golpe se cierra y vuelve la velocidad")
	assert_true(not player.counter.prompt.visible, "sin botón")
	await _done(tree, player)


func test_without_the_technique_there_is_no_window() -> void:
	var setup: Array = await _level(false)
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var enemy: Enemy = setup[2]
	enemy.telegraph(0.6)
	var opened := false
	for i in 50:
		opened = opened or player.counter.is_open()
		await tree.physics_frame
	assert_true(not opened, "sin la piedra de la Pradera no hay contraataque")
	await _done(tree, player)


func test_attacking_in_the_window_rolls_behind_and_hits_twice_as_hard() -> void:
	var setup: Array = await _level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var enemy: Enemy = setup[2]
	var before := enemy.health.current
	enemy.telegraph(1.0)
	await _until(tree, func() -> bool: return player.counter.is_open())
	_tap(player, &"attack")
	assert_true(await _until(tree, func() -> bool: return _state(player) == &"Countering", 10), "contraataca")
	assert_true(is_equal_approx(Engine.time_scale, 1.0), "al contraatacar vuelve la velocidad")
	assert_true(player.health.is_invulnerable(), "esquivando, no recibe daño")
	assert_true(await _until(tree, func() -> bool: return enemy.health.current < before), "le pega")
	var sword := player.equipment.weapon.make_damage(player).amount
	assert_eq(before - enemy.health.current, sword * 2, "×2 el daño de la espada")
	assert_true(enemy.bt_player.blackboard.get_var(Enemy.BB_STUNNED, false), "y lo aturde")
	assert_true(await _until(tree, func() -> bool: return _state(player) == &"Idle"), "y vuelve")
	await _done(tree, player)


func test_it_ends_behind_the_enemy() -> void:
	var setup: Array = await _level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var enemy: Enemy = setup[2]
	enemy.health.max_health = 400
	enemy.health.current = 400
	enemy.telegraph(1.0)
	await _until(tree, func() -> bool: return player.counter.is_open())
	_tap(player, &"attack")
	await _until(tree, func() -> bool: return player.attack_runner.is_running())
	assert_true(_behind(player, enemy), "termina a su espalda")
	await _done(tree, player)


func test_the_counter_gets_past_a_shield() -> void:
	var setup: Array = await _level(true, SHIELD_SKELETON)
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var enemy: Enemy = setup[2]
	assert_true(enemy.shield_up(), "el esqueleto con escudo se cubre de frente")
	var before := enemy.health.current
	enemy.telegraph(1.0)
	await _until(tree, func() -> bool: return player.counter.is_open())
	_tap(player, &"attack")
	assert_true(await _until(tree, func() -> bool: return enemy.health.current < before), "por la espalda el escudo no lo frena")
	await _done(tree, player)


func test_a_big_enemy_is_vaulted() -> void:
	var setup: Array = await _level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var enemy: Enemy = setup[2]
	enemy.config = enemy.config.duplicate()
	enemy.config.counter_vault = true
	var floor_y := player.global_position.y
	enemy.telegraph(1.0)
	await _until(tree, func() -> bool: return player.counter.is_open())
	_tap(player, &"attack")
	var top := 0.0
	for i in 60:
		top = maxf(top, player.global_position.y - floor_y)
		if player.attack_runner.is_running():
			break
		await tree.physics_frame
	assert_true(top > 1.0, "le salta por encima (%.2f m)" % top)
	assert_true(_behind(player, enemy), "y cae a su espalda")
	await _done(tree, player)


func test_the_slow_motion_can_be_turned_off() -> void:
	var setup: Array = await _level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var enemy: Enemy = setup[2]
	Settings.set_value(Counter.SLOW_SETTING, false)
	enemy.telegraph(1.0)
	assert_true(await _until(tree, func() -> bool: return player.counter.is_open()), "la ventana se abre igual")
	assert_true(is_equal_approx(Engine.time_scale, 1.0), "sin cámara lenta")
	await _done(tree, player)


func test_guarding_or_rolling_in_the_window_does_not_counter() -> void:
	var setup: Array = await _level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var enemy: Enemy = setup[2]
	enemy.telegraph(1.0)
	await _until(tree, func() -> bool: return player.counter.is_open())
	assert_true(player.is_blocking(), "fijado y cubriéndose")
	for i in 6:
		await tree.physics_frame
	assert_true(_state(player) != &"Countering", "cubrirse no contraataca")
	_tap(player, &"dodge")
	assert_true(await _until(tree, func() -> bool: return _state(player) == &"Dodging", 10), "rueda")
	assert_true(not player.counter.is_open(), "y rodando la ventana se cierra")
	await _done(tree, player)
