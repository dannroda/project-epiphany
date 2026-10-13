extends "res://tests/test_case.gd"
## Las sandalias (11.118): mantener toma impulso y corre recto hasta soltar o chocar; el choque golpea con `dash`; con la
## pluma en plena carrera, el salto largo cruza tres baldosas (6 m) y no cuatro (8 m), como pide el overworld (7.11).

const LEVEL := "res://levels/test.tscn"
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
	state.give(Items.get_item(&"feather"))
	state.assign_button(0, &"feather")
	state.give(Items.get_item(&"sandals"))
	state.assign_button(1, &"sandals")
	return [tree, player, state]


func _box(tree: SceneTree, center: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	tree.current_scene.add_child(body)
	body.global_position = center
	return body


func _press(action: StringName, pressed := true) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)


func _state(player: PlayerCharacter) -> StringName:
	return player.movement_state.get_active_state().name


func _dashing(player: PlayerCharacter) -> bool:
	return _state(player) == &"Dashing" and player.movement_state.get_active_state().running()


func _place(tree: SceneTree, player: PlayerCharacter, at: Vector3) -> void:
	player.global_position = at
	player.velocity = Vector3.ZERO
	for i in 10:
		await tree.physics_frame


func test_hold_winds_up_then_runs_straight_until_released() -> void:
	var setup: Array = await _level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	_box(tree, FAR + Vector3(0, -0.5, 0), Vector3(60, 1, 10))
	await _place(tree, player, FAR + Vector3(-25, 0, 0))
	_press(&"move_right")
	await tree.physics_frame
	_press(&"item_2")
	await tree.physics_frame
	await tree.physics_frame
	assert_eq(_state(player), &"Dashing", "mantener toma impulso")
	var still := player.global_position
	var drift := 0.0
	while _state(player) == &"Dashing" and not _dashing(player):
		drift = maxf(drift, player.global_position.distance_to(still))
		await tree.physics_frame
	assert_true(drift < 0.05, "en el lugar mientras toma impulso (%.2f)" % drift)
	_press(&"move_right", false)
	_press(&"move_up")
	await tree.create_timer(0.5).timeout
	assert_true(_dashing(player), "después corre")
	var from := player.global_position
	await tree.create_timer(0.5).timeout
	var run := player.global_position - from
	assert_true(run.x > 4.0, "rápido (%.2f m en 0,5 s)" % run.x)
	assert_true(absf(run.z) < 0.1, "recto, aunque se mueva el stick (z %.2f)" % run.z)
	_press(&"item_2", false)
	_press(&"move_up", false)
	await tree.create_timer(0.2).timeout
	assert_eq(_state(player), &"Idle", "al soltar se para")


func test_releasing_during_the_windup_cancels() -> void:
	var setup: Array = await _level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	_box(tree, FAR + Vector3(0, -0.5, 0), Vector3(20, 1, 10))
	await _place(tree, player, FAR)
	_press(&"item_2")
	await tree.create_timer(0.2).timeout
	_press(&"item_2", false)
	await tree.create_timer(0.6).timeout
	assert_eq(_state(player), &"Idle", "soltar antes de correr cancela")
	assert_true(player.global_position.distance_to(FAR) < 0.3, "sin moverse")


func test_crashing_bounces_and_hits_what_is_ahead_with_dash() -> void:
	var setup: Array = await _level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	_box(tree, FAR + Vector3(0, -0.5, 0), Vector3(30, 1, 10))
	_box(tree, FAR + Vector3(5, 1, 0), Vector3(1, 2, 6))
	var target := Hurtbox.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.6, 2, 2)
	shape.shape = box
	target.add_child(shape)
	tree.current_scene.add_child(target)
	target.global_position = FAR + Vector3(4.3, 1, 0)
	var hits: Array[DamageInfo] = []
	target.hit.connect(func(info: DamageInfo) -> void: hits.append(info))
	await _place(tree, player, FAR + Vector3(-6, 0, 0))
	_press(&"move_right")
	await tree.physics_frame
	_press(&"item_2")
	var crashed_at := 0.0
	for i in 180:
		await tree.physics_frame
		if not hits.is_empty():
			crashed_at = player.global_position.x
			break
	_press(&"move_right", false)
	assert_eq(hits.size(), 1, "el choque golpea lo de adelante una vez")
	if hits.is_empty():
		_press(&"item_2", false)
		return
	assert_eq(hits[0].element, &"dash", "con el elemento dash")
	await tree.create_timer(0.35).timeout
	assert_true(player.global_position.x < crashed_at - 0.3, "rebota (%.2f → %.2f)" % [crashed_at, player.global_position.x])
	_press(&"item_2", false)
	await tree.create_timer(0.2).timeout
	assert_eq(_state(player), &"Idle", "y se para aunque siga apretando")


## Corre hacia la derecha y salta con la pluma en el borde (x = FAR.x); devuelve dónde quedó.
func _long_jump(gap: float) -> Vector3:
	var setup: Array = await _level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	_box(tree, FAR + Vector3(-15, -0.5, 0), Vector3(30, 1, 10))
	_box(tree, FAR + Vector3(gap + 15, -0.5, 0), Vector3(30, 1, 10))
	await _place(tree, player, FAR + Vector3(-14, 0, 0))
	_press(&"move_right")
	await tree.physics_frame
	_press(&"item_2")
	for i in 240:
		await tree.physics_frame
		if player.global_position.x >= FAR.x - 0.15:
			break
	assert_true(_dashing(player), "llega corriendo al borde")
	_press(&"item_1")
	await tree.physics_frame
	_press(&"item_1", false)
	_press(&"item_2", false)
	_press(&"move_right", false)
	for i in 180:
		await tree.physics_frame
		if i > 5 and _state(player) != &"Jumping" or player.global_position.y < -3.0:
			break
	await tree.create_timer(0.2).timeout
	return player.global_position


func test_the_long_jump_clears_three_tiles() -> void:
	var landed := await _long_jump(6.0)
	assert_true(absf(landed.y - FAR.y) < 0.1 and landed.x > FAR.x + 6.0, "cruza 3 baldosas (x %.2f, y %.2f)" % [landed.x - FAR.x, landed.y - FAR.y])


func test_the_long_jump_does_not_clear_four_tiles() -> void:
	var landed := await _long_jump(8.0)
	assert_true(landed.y < FAR.y - 1.0, "4 baldosas no se cruzan: cae (x %.2f, y %.2f)" % [landed.x - FAR.x, landed.y - FAR.y])
