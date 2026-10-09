extends "res://tests/test_case.gd"


func _open_map(scenario := "test_rooms", level := "") -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	state.reset()
	if level.is_empty():
		await tree.root.get_node(^"SaveManager").load_scenario(scenario)
	else:
		tree.change_scene_to_file(level)
		await tree.scene_changed
	for i in 4:
		await tree.physics_frame
	var stack: Node = tree.root.get_node(^"MenuStack")
	var menu: Control = load("res://src/ui/menus/pause_menu.tscn").instantiate()
	stack.push(menu)
	menu.show_page(2)
	await tree.process_frame
	await tree.process_frame
	return [tree, state, stack, menu.pages.get_node(^"Mapa")]


func _cell(page: Control, room: String) -> MapRoomCell:
	return page.cells.get_node_or_null("Cell_" + room) as MapRoomCell


func _close(stack: Node) -> void:
	while stack.is_open():
		stack.pop()


func test_without_map_only_visited_rooms_show() -> void:
	var setup: Array = await _open_map()
	var state: Node = setup[1]
	var page: Control = setup[3]
	assert_eq(state.current_dungeon, &"test_rooms")
	assert_eq(page.title.text, "Salas de prueba")
	assert_eq(page.cells.get_child_count(), 1, "solo la sala donde está")
	var here := _cell(page, "RoomA")
	assert_true(here != null and here.here and here.state == MapRoomCell.State.CURRENT, "la sala actual con la flecha")
	assert_eq(_cell(page, "RoomC"), null, "una sala sin visitar no aparece")
	_close(setup[2])


func test_map_reveals_every_room() -> void:
	var setup: Array = await _open_map()
	var state: Node = setup[1]
	var page: Control = setup[3]
	state.give(Items.get_item(&"dungeon_map"))
	assert_eq(page.cells.get_child_count(), 3, "con el mapa aparecen todas")
	assert_eq(_cell(page, "RoomB").state, MapRoomCell.State.MAPPED, "sin visitar: punteada")
	assert_eq(_cell(page, "RoomC").closed_chests, 0, "sin brújula no se ven los cofres")
	assert_true(_cell(page, "RoomB").position.y < _cell(page, "RoomA").position.y, "B queda arriba de A")
	_close(setup[2])


func test_compass_marks_closed_chests() -> void:
	var setup: Array = await _open_map()
	var state: Node = setup[1]
	var page: Control = setup[3]
	state.give(Items.get_item(&"dungeon_map"))
	state.give(Items.get_item(&"compass"))
	assert_eq(_cell(page, "RoomC").closed_chests, 1, "el cofre de la sala C")
	assert_eq(_cell(page, "RoomA").closed_chests, 0)
	_close(setup[2])


func test_overworld_shows_marker_over_the_image() -> void:
	var setup: Array = await _open_map("", "res://levels/test.tscn")
	var tree: SceneTree = setup[0]
	var page: Control = setup[3]
	await tree.process_frame
	assert_true(page.overworld.visible and not page.cells.visible, "vista de overworld")
	assert_eq(page.title.text, "Campo de pruebas")
	assert_true(page.overworld_image.texture != null, "imagen del mapa")
	var image_rect := Rect2(page.overworld_image.position, page.overworld_image.size)
	assert_true(image_rect.has_point(page.marker.position), "el marcador cae sobre la imagen")
	_close(setup[2])
