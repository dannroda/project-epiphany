extends "res://tests/test_case.gd"
## 11.34: combo de tres golpes (tajo, revés, estocada) y giro cargado.

const LEVEL := "res://levels/test.tscn"


func _level() -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.get_node(^"GameState").reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	for enemy in tree.get_nodes_in_group(&"enemies"):
		enemy.free()
	var attacking := _attacking(player)
	attacking.entered.connect(func() -> void: attacking.set_meta(&"entered", attacking.get_meta(&"entered", 0) + 1))
	for i in 300:
		if _state(player) == &"Idle":
			break
		await tree.physics_frame
	return [tree, player]


func _event(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)


func _tap(action: StringName) -> void:
	_event(action, true)
	_event(action, false)


func _state(player: PlayerCharacter) -> StringName:
	return player.movement_state.get_active_state().name


func _attacking(player: PlayerCharacter) -> Node:
	return player.movement_state.get_node(^"Attacking")


func _until(tree: SceneTree, done: Callable, frames := 240) -> bool:
	for i in frames:
		if done.call():
			return true
		await tree.physics_frame
	return done.call()


func _until_cancel(tree: SceneTree, player: PlayerCharacter) -> void:
	var before: int = _attacking(player).get_meta(&"entered", 0)
	await _until(tree, func() -> bool: return _attacking(player).get_meta(&"entered", 0) > before and player.attack_runner.is_running())
	var attack := player.attack_runner.current
	await _until(tree, func() -> bool: return player.attack_runner.progress() >= attack.cancel_from)


func _done(tree: SceneTree) -> void:
	for action in [&"attack", &"z-lock", &"dodge"]:
		Input.action_release(action)
		_event(action, false)
	await tree.physics_frame
	tree.root.get_node(^"GameState").reset()


func test_three_hits_chain_inside_the_window() -> void:
	var setup: Array = await _level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var sword := player.equipment.weapon.behavior as MeleeBehavior
	var seen: Array[AttackData] = []
	for i in 3:
		_tap(&"attack")
		await _until_cancel(tree, player)
		seen.append(player.attack_runner.current)
	assert_eq(seen, sword.chain(), "tajo, revés y estocada")
	assert_true(sword.chain()[2].damage_multiplier > 1.0 and sword.chain()[2].knockback_multiplier > 1.0, "el tercero pega y empuja más")
	_tap(&"attack")
	await _until(tree, func() -> bool: return _attacking(player).step == 0 and player.attack_runner.progress() < 0.3)
	assert_eq(player.attack_runner.current, sword.attack, "después de la estocada vuelve al tajo")
	await _done(tree)


func test_the_combo_resets_outside_the_window() -> void:
	var setup: Array = await _level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var sword := player.equipment.weapon.behavior as MeleeBehavior
	_tap(&"attack")
	await _until_cancel(tree, player)
	await _until(tree, func() -> bool: return _state(player) == &"Idle")
	await tree.create_timer(_attacking(player).combo_window + 0.2).timeout
	_tap(&"attack")
	await _until(tree, func() -> bool: return player.attack_runner.is_running())
	assert_eq(player.attack_runner.current, sword.attack, "pasada la ventana, arranca de nuevo con el tajo")
	await _done(tree)


func test_a_roll_breaks_the_combo() -> void:
	var setup: Array = await _level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var sword := player.equipment.weapon.behavior as MeleeBehavior
	_tap(&"attack")
	await _until_cancel(tree, player)
	_tap(&"dodge")
	assert_true(await _until(tree, func() -> bool: return _state(player) == &"Dodging"), "rueda")
	await _until(tree, func() -> bool: return _state(player) == &"Idle")
	_tap(&"attack")
	await _until(tree, func() -> bool: return player.attack_runner.is_running())
	assert_eq(player.attack_runner.current, sword.attack, "después de rodar, el tajo")
	await _done(tree)


func test_holding_charges_and_releasing_spins() -> void:
	var setup: Array = await _level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var charge := player.sword_charge
	_event(&"attack", true)
	Input.action_press(&"attack")
	await tree.create_timer(charge.charge_time * 0.5).timeout
	assert_true(not charge.is_charged(), "a mitad de la carga todavía no")
	Input.action_release(&"attack")
	_event(&"attack", false)
	await tree.physics_frame
	await tree.physics_frame
	assert_true(_state(player) != &"Spinning", "soltar antes de tiempo no gira")
	await _until(tree, func() -> bool: return _state(player) == &"Idle")
	_event(&"attack", true)
	Input.action_press(&"attack")
	assert_true(await _until(tree, func() -> bool: return charge.is_charged(), 120), "mantener carga el giro")
	assert_true(charge.glow.current_animation == &"charged", "la espada brilla")
	Input.action_release(&"attack")
	_event(&"attack", false)
	assert_true(await _until(tree, func() -> bool: return _state(player) == &"Spinning", 10), "al soltar, gira")
	await _until(tree, func() -> bool: return player.attack_runner.is_active())
	assert_eq(player.attack_runner.current, (player.equipment.weapon.behavior as MeleeBehavior).spin, "con el golpe en redondo")
	assert_true(not charge.glow.get_parent().visible, "y se apaga el brillo")
	await _until(tree, func() -> bool: return _state(player) == &"Idle")
	await _done(tree)


func test_the_spin_hits_all_around() -> void:
	var setup: Array = await _level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var spin := player.attack_runner.hitboxes.get(&"spin") as Hitbox
	assert_true(spin != null and spin.team == player.config.team and spin.damage_factory.is_valid(), "la hitbox del giro hace daño del player")
	var shape := (spin.get_child(0) as CollisionShape3D).shape as CylinderShape3D
	assert_true(shape.radius > 1.2, "y abarca alrededor (%.1f m)" % shape.radius)
	await _done(tree)


func test_guarding_does_not_charge() -> void:
	var setup: Array = await _level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	Input.action_press(&"z-lock")
	await tree.physics_frame
	await tree.physics_frame
	assert_true(player.is_blocking(), "se cubre")
	_event(&"attack", true)
	Input.action_press(&"attack")
	await tree.create_timer(player.sword_charge.great_charge_time + 0.3).timeout
	assert_true(not player.sword_charge.is_charged() and not player.sword_charge.is_great_charged(), "cubriéndose no carga, ni el giro grande")
	Input.action_release(&"attack")
	_event(&"attack", false)
	for i in 4:
		await tree.physics_frame
	assert_true(_state(player) != &"Spinning", "ni gira al soltar")
	await _done(tree)


func test_rolling_does_not_charge() -> void:
	var setup: Array = await _level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	_tap(&"dodge")
	assert_true(await _until(tree, func() -> bool: return _state(player) == &"Dodging"), "rueda")
	Input.action_press(&"attack")
	var during := 0.0
	while _state(player) == &"Dodging":
		during = maxf(during, player.sword_charge.held)
		await tree.physics_frame
	Input.action_release(&"attack")
	assert_eq(during, 0.0, "rodando no carga")
	await _done(tree)


func test_holding_longer_charges_the_great_spin() -> void:
	var setup: Array = await _level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var charge := player.sword_charge
	var sword := player.equipment.weapon.behavior as MeleeBehavior
	_event(&"attack", true)
	Input.action_press(&"attack")
	assert_true(await _until(tree, func() -> bool: return charge.is_charged(), 120), "primero la carga normal")
	assert_true(not charge.is_great_charged() and charge.glow.current_animation == &"charged")
	assert_true(await _until(tree, func() -> bool: return charge.is_great_charged(), 180), "manteniendo más, la grande")
	assert_eq(charge.glow.current_animation, &"great", "con otro brillo")
	Input.action_release(&"attack")
	_event(&"attack", false)
	assert_true(await _until(tree, func() -> bool: return _state(player) == &"Spinning", 10), "al soltar, gira")
	await _until(tree, func() -> bool: return player.attack_runner.is_active())
	assert_eq(player.attack_runner.current, sword.great_spin, "el giro grande")
	assert_true(sword.great_spin.damage_multiplier > sword.spin.damage_multiplier, "pega más que el normal")
	await _until(tree, func() -> bool: return _state(player) == &"Idle")
	_event(&"attack", true)
	Input.action_press(&"attack")
	await _until(tree, func() -> bool: return charge.is_charged(), 120)
	Input.action_release(&"attack")
	_event(&"attack", false)
	await _until(tree, func() -> bool: return player.attack_runner.is_active() and _state(player) == &"Spinning")
	assert_eq(player.attack_runner.current, sword.spin, "soltando antes del segundo umbral, el normal")
	await _done(tree)


func test_the_great_spin_reaches_farther() -> void:
	var setup: Array = await _level()
	var player: PlayerCharacter = setup[1]
	var radius := func(name: StringName) -> float:
		var hitbox := player.attack_runner.hitboxes.get(name) as Hitbox
		return ((hitbox.get_child(0) as CollisionShape3D).shape as CylinderShape3D).radius
	assert_true(radius.call(&"great_spin") > radius.call(&"spin"), "el grande abarca más (%.1f > %.1f m)" % [radius.call(&"great_spin"), radius.call(&"spin")])
	await _done(setup[0])
