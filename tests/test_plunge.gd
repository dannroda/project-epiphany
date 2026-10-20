extends "res://tests/test_case.gd"
## 11.34 paso 4: golpe en picada. Atacar en el aire del salto de la pluma cae clavando la espada; la onda pega ×2 en
## 1,2 m y hunde las placas STRIKE sin ser golpe fuerte (no rompe lo que pide el martillo).

const LEVEL := "res://levels/test.tscn"
const FLOOR_SWITCH := preload("res://src/world/floor_switch.tscn")
const WAVE := preload("res://src/combat/plunge_wave.tscn")


func _level(learned := true) -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	var state := tree.root.get_node(^"GameState")
	state.reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	var enemy := tree.current_scene.get_node(^"Enemy") as Enemy
	for other in tree.get_nodes_in_group(&"enemies"):
		if other != enemy:
			other.free()
	state.give(Items.get_item(&"feather"))
	state.assign_button(0, &"feather")
	if learned:
		state.set_flag(Plunging.LEARNED, true)
	for i in 300:
		if _state(player) == &"Idle":
			break
		await tree.physics_frame
	enemy.bt_player.active = false
	enemy.global_position = player.global_position + Vector3(0.9, 0, 0)
	return [tree, player, enemy]


func _press(action: StringName) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
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


func _jump_and_attack(tree: SceneTree, player: PlayerCharacter) -> void:
	_press(&"item_1")
	var jumping := player.movement_state.get_node(^"Jumping")
	await _until(tree, func() -> bool: return _state(player) == &"Jumping" and jumping.airborne_height() > 0.3, 60)
	_press(&"attack")


func _done(tree: SceneTree) -> void:
	await tree.physics_frame
	tree.root.get_node(^"GameState").reset()


func test_attacking_in_the_air_plunges_and_the_wave_hits_twice_as_hard() -> void:
	var setup: Array = await _level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var enemy: Enemy = setup[2]
	var before := enemy.health.current
	await _jump_and_attack(tree, player)
	assert_true(await _until(tree, func() -> bool: return _state(player) == &"Plunging", 10), "clava el golpe en picada")
	assert_true(await _until(tree, func() -> bool: return player.is_on_floor() and enemy.health.current < before, 60), "la onda le pega al caer")
	assert_eq(before - enemy.health.current, player.equipment.weapon.make_damage(player).amount * 2, "×2 el daño de la espada")
	assert_true(await _until(tree, func() -> bool: return _state(player) == &"Idle"), "y vuelve")
	await _done(tree)


func test_the_wave_presses_a_strike_plate() -> void:
	var setup: Array = await _level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var enemy: Enemy = setup[2]
	enemy.free()
	var plate := FLOOR_SWITCH.instantiate() as FloorSwitch
	plate.mode = FloorSwitch.Mode.STRIKE
	tree.current_scene.add_child(plate)
	plate.global_position = player.global_position + Vector3(0.8, 0, 0)
	await tree.physics_frame
	await _jump_and_attack(tree, player)
	assert_true(await _until(tree, func() -> bool: return plate.active, 90), "la placa STRIKE se hunde")
	await _done(tree)


func test_the_wave_is_a_slam_not_a_strong_blow() -> void:
	var setup: Array = await _level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var wave := WAVE.instantiate() as Hitbox
	wave.damage_factory = player._make_damage
	tree.current_scene.add_child(wave)
	wave.global_position = Vector3(300, 0, 0)
	var info := wave.build_damage()
	assert_true(info.slam and not info.strong, "hunde placas pero no rompe lo del martillo ni guardias")
	var shape := (wave.get_child(0) as CollisionShape3D).shape as CylinderShape3D
	assert_true(is_equal_approx(shape.radius, 1.2), "1,2 m alrededor")
	await _done(tree)


func test_without_the_technique_the_attack_waits_for_the_landing() -> void:
	var setup: Array = await _level(false)
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	await _jump_and_attack(tree, player)
	var plunged := false
	for i in 60:
		plunged = plunged or _state(player) == &"Plunging"
		await tree.physics_frame
	assert_true(not plunged, "sin la piedra de la Arboleda no hay golpe en picada")
	await _done(tree)
