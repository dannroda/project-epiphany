extends "res://tests/test_case.gd"

const OVERWORLD := "res://levels/overworld.tscn"
const DUNGEON := "res://levels/temple.tscn"
const SLOT := 9
const WARP := preload("res://src/world/warp_portal.tscn")


func _walk(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	event.strength = 1.0
	Input.parse_input_event(event)


## Camina hasta llegar a `scene_path` y espera a que termine el viaje.
func _walk_into(tree: SceneTree, action: StringName, scene_path: String) -> bool:
	var saves: Node = tree.root.get_node(^"SaveManager")
	_walk(action, true)
	var until := Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < until and not tree.root.get_node(^"SceneFlow").traveling:
		await tree.physics_frame
	_walk(action, false)
	while Time.get_ticks_msec() < until and tree.root.get_node(^"SceneFlow").traveling:
		await tree.process_frame
	for enemy in tree.get_nodes_in_group(&"enemies"):
		enemy.free()
	await tree.physics_frame
	return tree.current_scene != null and tree.current_scene.scene_file_path == scene_path


func _player(tree: SceneTree) -> PlayerCharacter:
	return tree.get_first_node_in_group(&"player") as PlayerCharacter


func test_enter_and_leave_the_temple_keeping_the_dungeon() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	var saves: Node = tree.root.get_node(^"SaveManager")
	state.reset()
	state.set_flag(&"ow_temple_seal_open", true)
	saves.current_slot = SLOT
	tree.change_scene_to_file(OVERWORLD)
	await tree.scene_changed
	for enemy in tree.get_nodes_in_group(&"enemies"):
		enemy.free()
	_player(tree).global_position = Vector3(-42, 5.2, -33)
	await tree.create_timer(0.3).timeout

	assert_true(await _walk_into(tree, &"move_forward", DUNGEON), "la puerta del templo lleva a la mazmorra")
	assert_eq(state.current_dungeon, &"d1", "la mazmorra queda activa")
	assert_true(_player(tree).global_position.distance_to(Vector3(24, 0, 68)) < 0.8, "aparece en la entrada (%s)" % _player(tree).global_position)
	assert_eq(tree.paused, false, "el juego sigue al terminar el fundido")
	var camera := tree.current_scene.get_node(^"TopDownCamera") as TopDownCamera
	assert_eq(camera.room, tree.current_scene.get_node(^"Vestibulo"), "la cámara toma la sala de entrada")
	var autosave := ConfigFile.new()
	assert_eq(SaveCodec.read(saves.slot_path(SLOT), autosave), OK, "guardó al cambiar de escena")
	assert_eq(autosave.get_value("player", "spawn_scene", ""), DUNGEON)
	assert_eq(autosave.get_value("player", "spawn_point", &""), &"start")
	state.give(Items.get_item(&"small_key"))

	assert_true(await _walk_into(tree, &"move_backward", OVERWORLD), "la salida vuelve al overworld")
	assert_eq(state.current_dungeon, &"", "fuera de la mazmorra")
	assert_true(_player(tree).global_position.distance_to(Vector3(-42, 5.2, -33)) < 0.8, "aparece frente al templo (%s)" % _player(tree).global_position)
	camera = tree.current_scene.get_node(^"TopDownCamera") as TopDownCamera
	assert_true((camera.global_position - camera.offset).distance_to(_player(tree).global_position) < 1.0, "la cámara arranca sobre el player")

	assert_true(await _walk_into(tree, &"move_forward", DUNGEON), "se puede volver a entrar")
	assert_eq(state.current_dungeon_state().small_keys, 1, "la mazmorra conserva su estado")
	assert_true(state.current_dungeon_state().was_visited(0), "y las salas visitadas")
	assert_true(_player(tree).global_position.distance_to(Vector3(24, 0, 68)) < 0.8, "otra vez en la entrada")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(saves.slot_path(SLOT)))
	saves.current_slot = 1
	state.reset()


func _spawn(flag: StringName) -> Portal:
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.get_node(^"GameState").reset()
	var portal: Portal = WARP.instantiate()
	portal.required_flag = flag
	tree.root.add_child(portal)
	await tree.physics_frame
	await tree.physics_frame
	return portal


func test_without_flag_is_always_open() -> void:
	var portal := await _spawn(&"")
	assert_true(portal.visible)
	assert_true(portal.monitoring)
	portal.free()


func test_flag_opens_it() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var portal := await _spawn(&"d1_boss_door")
	assert_true(not portal.visible, "cerrado hasta el flag")
	assert_true(not portal.monitoring)
	tree.root.get_node(^"GameState").set_flag(&"d1_boss_door", true)
	await tree.physics_frame
	assert_true(portal.visible, "aparece con el flag")
	assert_true(portal.monitoring)
	portal.free()


func test_boss_room_has_exit_to_temple_entrance() -> void:
	var temple: Node = load("res://levels/temple.tscn").instantiate()
	var portal := temple.get_node(^"BossExitPortal") as Portal
	assert_true(portal != null)
	assert_eq(portal.target_scene, "res://levels/overworld.tscn")
	assert_eq(portal.target_spawn, &"templo")
	assert_eq(portal.required_flag, &"d1_boss_defeated", "aparece al vencer al jefe")
	var boss_room := temple.get_node(^"Jefe") as Room
	var shape := boss_room.get_node(^"CollisionShape3D") as CollisionShape3D
	var size := (shape.shape as BoxShape3D).size
	var local := portal.position - boss_room.position
	assert_true(absf(local.x) < size.x / 2.0 and absf(local.z) < size.z / 2.0, "adentro de la sala del jefe")
	temple.free()
