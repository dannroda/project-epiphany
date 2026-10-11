extends "res://tests/test_case.gd"

const TEST_SETTINGS := "user://test_settings.cfg"


func _load(scenario := "", level := "") -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	var settings: Node = tree.root.get_node(^"Settings")
	settings.path = TEST_SETTINGS
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	settings.load_settings()
	state.reset()
	if scenario.is_empty():
		tree.change_scene_to_file(level)
		await tree.scene_changed
	else:
		await tree.root.get_node(^"SaveManager").load_scenario(scenario)
	for i in 6:
		await tree.process_frame
	var minimap: Control = tree.get_first_node_in_group(&"hud").get_node(^"%Minimap")
	return [tree, state, settings, minimap]


func test_dungeon_shows_the_rooms_around_and_hides_with_menus_or_option() -> void:
	var setup: Array = await _load("test_rooms")
	var tree: SceneTree = setup[0]
	var state: Node = setup[1]
	var settings: Node = setup[2]
	var minimap: Control = setup[3]
	assert_true(minimap.visible, "se ve en la mazmorra")
	var shown: Array = minimap.rooms_around()
	assert_eq(shown.size(), 1, "sin mapa, solo la sala actual")
	state.current_dungeon_state().has_map = true
	assert_true(minimap.rooms_around().size() > 1, "con el mapa, también las vecinas")
	var stack: Node = tree.root.get_node(^"MenuStack")
	stack.push(load("res://src/ui/menus/pause_menu.tscn").instantiate())
	await tree.process_frame
	assert_true(not minimap.visible, "con un menú abierto no se ve")
	while stack.is_open():
		stack.pop()
	await tree.process_frame
	assert_true(minimap.visible, "vuelve al cerrarlo")
	settings.set_value(&"minimap", false)
	await tree.process_frame
	assert_true(not minimap.visible, "se apaga desde Opciones")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	settings.load_settings()
	state.reset()


func test_hidden_in_the_boss_room() -> void:
	var setup: Array = await _load("", "res://levels/temple.tscn")
	var tree: SceneTree = setup[0]
	var minimap: Control = setup[3]
	assert_true(minimap.visible, "se ve en el vestíbulo")
	var boss_room: Room = tree.get_nodes_in_group(Room.GROUP).filter(func(room: Room) -> bool: return room.boss_room)[0]
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	var center := boss_room.bounds().get_center()
	player.global_position = Vector3(center.x, player.global_position.y, center.y + 3.0)
	for i in 20:
		await tree.process_frame
	assert_true(not minimap.visible, "en la guarida del jefe no se ve")
	setup[1].reset()


func test_overworld_shows_the_photo_around_the_player() -> void:
	var setup: Array = await _load("", "res://levels/overworld.tscn")
	var minimap: Control = setup[3]
	assert_true(minimap.visible, "se ve en el overworld")
	assert_true(minimap._map != null and minimap._map.texture != null, "con la foto cenital del overworld")
	assert_eq(minimap.rooms_around().size(), 0, "sin salas")
	setup[1].reset()
