extends "res://tests/test_case.gd"
## La pluma (11.35): saltar con el ítem, cruzar un hueco de una baldosa, no pasar una pirca y esquivar la onda del jefe.

const LEVEL := "res://levels/test.tscn"
## Lejos de todo lo del nivel de prueba.
const FAR := Vector3(200, 0, 0)


func _level() -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	var state := tree.root.get_node(^"GameState")
	state.reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	for i in 300:
		if _state(player) == &"Idle":
			break
		await tree.physics_frame
	return [tree, player, state]


func _give_feather(state: Node) -> void:
	state.give(Items.get_item(&"feather"))
	state.assign_button(0, &"feather")


func _box(tree: SceneTree, center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	tree.current_scene.add_child(body)
	body.global_position = center


func _press(action: StringName, held := false) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	Input.parse_input_event(press)
	if held:
		return
	var release := InputEventAction.new()
	release.action = action
	Input.parse_input_event(release)


func _release(action: StringName) -> void:
	var release := InputEventAction.new()
	release.action = action
	Input.parse_input_event(release)


func _state(player: PlayerCharacter) -> StringName:
	return player.movement_state.get_active_state().name


## Salta hacia la derecha desde `from` y devuelve dónde quedó al aterrizar.
func _jump_right(tree: SceneTree, player: PlayerCharacter, from: Vector3) -> Vector3:
	player.global_position = from
	for i in 10:
		await tree.physics_frame
	_press(&"move_right", true)
	await tree.physics_frame
	_press(&"item_1")
	for i in 120:
		await tree.physics_frame
		if i > 5 and _state(player) != &"Jumping":
			break
	_release(&"move_right")
	for i in 20:
		await tree.physics_frame
	return player.global_position


func test_without_the_feather_nothing_jumps() -> void:
	var setup: Array = await _level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	_press(&"item_1")
	for i in 10:
		await tree.physics_frame
		assert_true(_state(player) != &"Jumping", "sin la pluma no hay salto")


func test_feather_jumps_a_fixed_arc_and_lands() -> void:
	var setup: Array = await _level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	_give_feather(setup[2])
	_box(tree, FAR + Vector3(0, -0.5, 0), Vector3(20, 1, 20))
	player.global_position = FAR
	for i in 10:
		await tree.physics_frame
	var shadow := player.get_node(^"%JumpShadow") as Decal
	_press(&"item_1")
	var apex := 0.0
	var shadow_seen := false
	for i in 120:
		await tree.physics_frame
		apex = maxf(apex, player.global_position.y - FAR.y)
		shadow_seen = shadow_seen or shadow.visible
		if i > 5 and _state(player) != &"Jumping":
			break
	assert_true(apex > 0.6, "sube más que un escalón y que la onda del jefe (%.2f)" % apex)
	assert_true(apex < 0.75, "no llega a apoyarse en una pirca (%.2f)" % apex)
	assert_true(shadow_seen, "la sombra marca dónde cae")
	assert_eq(_state(player), &"Idle", "aterriza y vuelve")
	assert_true(not shadow.visible, "la sombra se va al aterrizar")
	assert_true(player.is_on_floor())


func test_clears_a_one_tile_gap() -> void:
	var setup: Array = await _level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	_give_feather(setup[2])
	_box(tree, FAR + Vector3(-5, -0.5, 0), Vector3(10, 1, 10))
	_box(tree, FAR + Vector3(7, -0.5, 0), Vector3(10, 1, 10))
	var landed := await _jump_right(tree, player, FAR + Vector3(-0.4, 0, 0))
	assert_true(landed.x - FAR.x > 2.0, "cruzó los 2 m del hueco (x %.2f)" % (landed.x - FAR.x))
	assert_true(absf(landed.y - FAR.y) < 0.1, "y quedó en el piso de enfrente (y %.2f)" % (landed.y - FAR.y))


func test_does_not_clear_a_low_wall() -> void:
	var setup: Array = await _level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	_give_feather(setup[2])
	_box(tree, FAR + Vector3(0, -0.5, 0), Vector3(20, 1, 20))
	_box(tree, FAR + Vector3(1.2, 0.45, 0), Vector3(0.3, 0.9, 20))
	var landed := await _jump_right(tree, player, FAR + Vector3(-0.2, 0, 0))
	assert_true(landed.x - FAR.x < 1.0, "la pirca de 0,9 m lo frena (x %.2f)" % (landed.x - FAR.x))
	assert_true(landed.y - FAR.y < 0.1, "y no queda parado en su borde (y %.2f)" % (landed.y - FAR.y))


func test_hops_onto_a_step() -> void:
	var setup: Array = await _level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	_give_feather(setup[2])
	_box(tree, FAR + Vector3(0, -0.5, 0), Vector3(20, 1, 20))
	_box(tree, FAR + Vector3(3, 0.3, 0), Vector3(3, 0.6, 20))
	var landed := await _jump_right(tree, player, FAR + Vector3(0.2, 0, 0))
	assert_true(absf(landed.y - FAR.y - 0.6) < 0.1, "subió al escalón de 0,6 m (y %.2f)" % (landed.y - FAR.y))


## Al costado del golpe de una mano: fuera de la mano, dentro de la onda. Salta `jump_before` antes del impacto
## (0 = no salta). La onda es `ground_only`: alcanza con estar en el aire cuando llega.
func _slam_beside(jump_before: float) -> int:
	var tree := Engine.get_main_loop() as SceneTree
	var state := tree.root.get_node(^"GameState")
	state.reset()
	_give_feather(state)
	tree.change_scene_to_file("res://levels/templo.tscn")
	await tree.scene_changed
	var level := tree.current_scene
	(level.get_node(^"BossArena") as BossArena).started = true
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	player.global_position = Vector3(44, 0, 11)
	for i in 10:
		await tree.physics_frame
	var hand := (level.get_node(^"Boss") as Boss).hand_left
	var before := player.health.current
	hand.perform(load("res://data/boss/attack_slam.tres"), player, (level.get_node(^"Boss") as Boss).arena)
	await tree.create_timer(hand.slam_rise_time + hand.slam_track_time + 0.05).timeout
	player.global_position += Vector3(2.0, 0, 0)
	var impact := hand.slam_lock_time - 0.05 + 0.09
	if jump_before > 0.0:
		await tree.create_timer(impact - jump_before).timeout
		_press(&"item_1")
	await tree.create_timer(1.0).timeout
	var lost: int = before - player.health.current
	state.reset()
	return lost


func test_jumping_dodges_the_slam_shockwave() -> void:
	assert_true(await _slam_beside(0.0) > 0, "quieto al lado del golpe, la onda pega")
	assert_eq(await _slam_beside(0.3), 0, "en el aire cuando llega, no le pega")


func test_the_crag_abyss_is_too_wide_and_falling_returns() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state := tree.root.get_node(^"GameState")
	state.reset()
	_give_feather(state)
	tree.change_scene_to_file("res://levels/overworld.tscn")
	await tree.scene_changed
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	player.global_position = Vector3(80, 5.3, -22.4)
	for i in 20:
		await tree.physics_frame
	var before := player.health.current
	_press(&"move_forward", true)
	await tree.physics_frame
	_press(&"item_1")
	var lowest := player.global_position.y
	for i in 180:
		await tree.physics_frame
		lowest = minf(lowest, player.global_position.y)
		if lowest < 4.7:
			_release(&"move_forward")
	_release(&"move_forward")
	var spawn := tree.current_scene.get_node(^"Spawn_risco") as Node3D
	assert_true(lowest < 4.7, "el abismo de 4 m no se cruza saltando: cae (y mín %.2f)" % lowest)
	assert_true(player.health.current < before, "caer saca vida")
	assert_true(player.global_position.z > -23.0, "y vuelve a la cornisa (z %.2f)" % player.global_position.z)
	assert_true(player.global_position.distance_to(spawn.global_position) < 6.0, "cerca de Spawn_risco")
	state.reset()


func _overworld(feather: bool) -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	var state := tree.root.get_node(^"GameState")
	state.reset()
	if feather:
		_give_feather(state)
	tree.change_scene_to_file("res://levels/overworld.tscn")
	await tree.scene_changed
	for enemy in tree.get_nodes_in_group(&"enemies"):
		enemy.free()
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	player.health.invulnerability_time = 0.0
	return [tree, player, state]


## Camina hacia un lado (saltando si hay pluma) y devuelve dónde quedó y lo más bajo que estuvo.
func _try(tree: SceneTree, player: PlayerCharacter, from: Vector3, action: StringName, jump: bool) -> Array:
	player.global_position = from
	for i in 20:
		await tree.physics_frame
	_press(action, true)
	await tree.physics_frame
	if jump:
		_press(&"item_1")
	var lowest := player.global_position.y
	for i in 70:
		await tree.physics_frame
		lowest = minf(lowest, player.global_position.y)
		if lowest < -0.5:
			break
	_release(action)
	for i in 60:
		await tree.physics_frame
	return [player.global_position, lowest]


func test_meadow_heart_piece_sits_on_a_step() -> void:
	var setup: Array = await _overworld(false)
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var state: Node = setup[2]
	var walked: Array = await _try(tree, player, Vector3(-46.6, 0, -10), &"move_left", false)
	assert_true(walked[0].y < 0.1, "sin pluma el escalón no se sube (y %.2f)" % walked[0].y)
	assert_eq(state.get_flag(&"ow_heart_piece_meadow"), false, "ni se toma la pieza")
	setup = await _overworld(true)
	tree = setup[0]
	player = setup[1]
	state = setup[2]
	await _try(tree, player, Vector3(-47.2, 0, -10), &"move_left", true)
	assert_eq(state.get_flag(&"ow_heart_piece_meadow"), true, "con la pluma sube al escalón y toma la pieza")
	var stack: Node = tree.root.get_node(^"MenuStack")
	for i in 120:
		if stack.is_open():
			break
		await tree.process_frame
	while stack.is_open():
		stack.pop()
	state.reset()


func test_the_narrows_are_too_wide_for_the_feather_alone() -> void:
	var setup: Array = await _overworld(false)
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var before := player.health.current
	var walked: Array = await _try(tree, player, Vector3(-6, 0, 18), &"move_right", false)
	assert_true(walked[1] < -0.5, "sin pluma cae en la angostura (y mín %.2f)" % walked[1])
	assert_true(player.health.current < before, "caer lastima")
	assert_true(walked[0].x < -5.0 and walked[0].y > -0.5, "y vuelve del lado de la Arboleda (%s)" % walked[0])
	setup = await _overworld(true)
	tree = setup[0]
	player = setup[1]
	var jumped: Array = await _try(tree, player, Vector3(-5.6, 0, 18), &"move_right", true)
	assert_true(jumped[1] < -0.5, "con la pluma sola tampoco: son tres celdas (y mín %.2f)" % jumped[1])
	assert_true(jumped[0].x < -5.0, "y vuelve del lado de la Arboleda (%s)" % jumped[0])
	(setup[2] as Node).reset()

func test_the_ravine_ledge_takes_one_feather_jump() -> void:
	var setup: Array = await _overworld(true)
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var state: Node = setup[2]
	state.give(Items.get_item(&"bow"))
	var landed := await _jump_right(tree, player, Vector3(-9.6, 0, -32.4))
	assert_true(landed.y > -0.5 and landed.x > -7.2 and landed.x < -4.8, "un salto de pluma llega a la repisa (%s)" % landed)
	var chest := tree.current_scene.get_node(^"SecretLedgeChest") as Chest
	var before: int = state.inventory.count(&"arrow")
	chest.interactable.interact(player)
	await tree.create_timer(1.0).timeout
	var stack: Node = tree.root.get_node(^"MenuStack")
	while stack.is_open():
		stack.pop()
	await tree.create_timer(1.2).timeout
	assert_true(state.inventory.count(&"arrow") > before, "y su cofre tiene flechas")
	state.reset()


func test_the_grove_gap_takes_one_feather_jump() -> void:
	var setup: Array = await _overworld(true)
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var landed := await _jump_right(tree, player, Vector3(-43.6, 2.7, 23))
	assert_true(landed.y > 2.0 and landed.x > -41.0, "un salto de pluma cruza de la cornisa del claro a la Arboleda (%s)" % landed)
	(setup[2] as Node).reset()
