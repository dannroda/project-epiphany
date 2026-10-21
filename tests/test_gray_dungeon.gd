extends "res://tests/test_case.gd"

const SLOT := 7


func _wait(tree: SceneTree, seconds: float) -> void:
	await tree.create_timer(seconds).timeout


func _move_to(tree: SceneTree, player: PlayerCharacter, at: Vector3) -> void:
	player.global_position = at
	player.velocity = Vector3.ZERO
	await _wait(tree, 1.0)


func _open_chest(tree: SceneTree, chest: Chest, player: PlayerCharacter) -> void:
	var stack: Node = tree.root.get_node(^"MenuStack")
	chest.interactable.interact(player)
	await _wait(tree, 1.0)
	while stack.is_open():
		stack.pop()
	await _wait(tree, 1.2)


func test_walk_the_three_rooms_and_reload() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	var saves: Node = tree.root.get_node(^"SaveManager")
	state.reset()
	assert_eq(await saves.load_scenario("dungeon_test"), OK)
	await _wait(tree, 0.5)
	var level := tree.current_scene
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	var camera := level.get_node(^"TopDownCamera") as TopDownCamera
	var switch_door := level.get_node(^"SwitchDoor") as Door
	var shutter := level.get_node(^"GuardShutter") as Door
	var locked := level.get_node(^"LockedDoor") as Door
	assert_eq(state.current_dungeon, &"d0", "mazmorra d0")
	assert_eq(camera.room, level.get_node(^"Vestibulo"), "arranca en el vestíbulo")
	assert_eq(switch_door.is_open, false, "la puerta oeste espera al interruptor")

	await _move_to(tree, player, Vector3(-5, 0, -1))
	var block := level.get_node(^"Block") as PushBlock
	for direction in [Vector3.RIGHT, Vector3.RIGHT, Vector3.FORWARD, Vector3.FORWARD]:
		assert_true(block.try_push(direction), "el bloque se mueve hacia %s" % direction)
		await _wait(tree, 0.6)
	assert_true(block.global_position.is_equal_approx(Vector3(2, 0, -2)), "bloque sobre el interruptor")
	await _wait(tree, 0.8)
	assert_eq(state.get_flag(&"d0_gray_switch"), true, "el interruptor queda marcado")
	assert_eq(switch_door.is_open, true, "el interruptor abre la puerta oeste")

	await _move_to(tree, player, Vector3(-11, 0, 0))
	assert_eq(camera.room, level.get_node(^"Guardia"), "pasa a la sala de guardia")
	assert_eq(shutter.is_open, false, "la persiana se cierra con los esqueletos adentro")
	for skeleton_name in [^"Skeleton1", ^"Skeleton2"]:
		var skeleton: Node = level.get_node(skeleton_name)
		skeleton.health.invulnerability_time = 0.0
		skeleton.health.damage(100)
	await _wait(tree, 0.8)
	assert_eq(shutter.is_open, true, "sin esqueletos se abre")
	await _move_to(tree, player, Vector3(-30, 0, 0))
	await _open_chest(tree, level.get_node(^"KeyChest"), player)
	assert_eq(state.current_dungeon_state().small_keys, 1, "la llave estaba en la sala lateral")

	await _move_to(tree, player, Vector3(0, 0, -3))
	assert_eq(camera.room, level.get_node(^"Vestibulo"))
	locked.interactable.interact(player)
	assert_eq(locked.is_open, true, "la llave abre la puerta norte")
	assert_eq(state.current_dungeon_state().small_keys, 0, "gasta la llave")
	await _move_to(tree, player, Vector3(0, 0, -10))
	assert_eq(camera.room, level.get_node(^"Camara"), "entra a la cámara sellada")
	await _open_chest(tree, level.get_node(^"CompassChest"), player)
	assert_eq(state.current_dungeon_state().has_compass, true, "la brújula estaba en la cámara")

	assert_eq(saves.save_game(SLOT), OK)
	state.reset()
	tree.change_scene_to_file("res://levels/test/test.tscn")
	await tree.scene_changed
	assert_eq(await saves.load_game(SLOT), OK)
	await _wait(tree, 0.5)
	level = tree.current_scene
	camera = level.get_node(^"TopDownCamera")
	assert_eq(level.scene_file_path, "res://levels/test/dungeon_test.tscn")
	assert_eq(camera.room, level.get_node(^"Camara"), "vuelve a la sala 3")
	assert_eq((level.get_node(^"SwitchDoor") as Door).is_open, true, "puerta oeste abierta tras cargar")
	assert_eq((level.get_node(^"LockedDoor") as Door).is_open, true, "puerta con llave abierta tras cargar")
	assert_true((level.get_node(^"Block") as Node3D).global_position.is_equal_approx(Vector3(2, 0, -2)), "el bloque queda resuelto")
	assert_eq((level.get_node(^"KeyChest") as Chest).interactable.enabled, false, "cofre de la llave abierto")
	assert_eq((level.get_node(^"CompassChest") as Chest).interactable.enabled, false, "cofre de la brújula abierto")
	assert_eq(state.current_dungeon_state().has_compass, true, "brújula tras cargar")
	assert_eq(state.current_dungeon_state().small_keys, 0, "sin llaves tras cargar")
	assert_eq(state.current_dungeon_state().visited_rooms, 0b111, "las tres salas visitadas")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saves.slot_path(SLOT)))
	state.reset()
