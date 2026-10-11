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
	return page.rooms_layer.get_node_or_null("Cell_" + room) as MapRoomCell


func _close(stack: Node) -> void:
	while stack.is_open():
		stack.pop()


func test_without_map_only_visited_rooms_show() -> void:
	var setup: Array = await _open_map()
	var state: Node = setup[1]
	var page: Control = setup[3]
	assert_eq(state.current_dungeon, &"test_rooms")
	assert_eq(page.title.text, "Salas de prueba")
	assert_eq(page.rooms_layer.get_child_count(), 1, "solo la sala donde está")
	var here := _cell(page, "RoomA")
	assert_true(here != null and here.here and here.state == MapRoomCell.State.CURRENT, "la sala actual con la flecha")
	assert_eq(_cell(page, "RoomC"), null, "una sala sin visitar no aparece")
	_close(setup[2])


func test_map_reveals_every_room() -> void:
	var setup: Array = await _open_map()
	var state: Node = setup[1]
	var page: Control = setup[3]
	state.give(Items.get_item(&"dungeon_map"))
	assert_eq(page.rooms_layer.get_child_count(), 3, "con el mapa aparecen todas")
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


func test_clicking_a_tab_switches_the_page() -> void:
	var opened := await _open_map()
	var stack: Node = opened[2]
	var menu: Control = stack.top()
	menu.tabs.current_tab = 1
	assert_eq(menu.current, 1, "el clic en la pestaña cambia la página")
	assert_eq(menu.pages.get_current_tab_control().name, &"Ítems")
	menu.show_page(menu.current + 4)
	assert_eq(menu.tabs.current_tab, 1, "Q/E da la vuelta y la barra la sigue")
	_close(stack)


func _press(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	var release := InputEventAction.new()
	release.action = action
	Input.parse_input_event(release)


func test_overworld_fog_lifts_as_zones_are_visited() -> void:
	var setup: Array = await _open_map("", "res://levels/overworld.tscn")
	var tree: SceneTree = setup[0]
	var state: Node = setup[1]
	var page: Control = setup[3]
	await tree.process_frame
	var zones: int = page._zones().size()
	assert_eq(state.visited_zones, [&"Zone_start"] as Array[StringName], "partida nueva: solo el claro del inicio")
	assert_eq(page.fog.get_child_count(), zones - 1, "las demás en sombra")
	assert_true(page.fog.get_children().all(func(zone: Control) -> bool: return zone.size.x > 20.0 and zone.position != Vector2.ZERO), "cada sombra cubre su zona")
	assert_eq(page.subtitle.text, tr("MAP_ZONES_EXPLORED").format({done = 1, total = zones}))
	state.visit_zone(&"Zone_pradera")
	page.refresh()
	await tree.process_frame
	await tree.process_frame
	assert_eq(page.fog.get_child_count(), zones - 2, "la pradera se destapa")
	_close(setup[2])
	state.reset()


func test_cursor_reads_what_is_missing_in_a_zone() -> void:
	var setup: Array = await _open_map("", "res://levels/overworld.tscn")
	var tree: SceneTree = setup[0]
	var state: Node = setup[1]
	var page: Control = setup[3]
	state.visit_zone(&"Zone_gruta")
	page.refresh()
	await tree.process_frame
	await tree.process_frame
	var grotto: AreaZone = tree.current_scene.get_node(^"Zone_gruta")
	page._move_cursor(page.world_to_map(grotto.bounds().get_center()))
	assert_eq(page.focus_title.text, "PLACE_HIDDEN_GROTTO")
	var rows: Array = page.focus_stats.get_children().map(func(row: StatRow) -> String: return row.get_node(^"Padding/Row/Name").text + "=" + row.value_text())
	assert_true(rows.has("MAP_HEART_PIECES=" + tr("MAP_COUNT").format({done = 0, total = 1})), "dice que falta la pieza (%s)" % [rows])
	assert_true(rows.has("MAP_CHESTS=" + tr("MAP_COUNT").format({done = 0, total = 1})), "y el cofre")
	var risk: AreaZone = tree.current_scene.get_node(^"Zone_risco")
	page._move_cursor(page.world_to_map(risk.bounds().get_center()))
	assert_eq(page.focus_text.text, "MAP_UNEXPLORED", "de las zonas sin ver no cuenta nada")
	_close(setup[2])
	state.reset()


func test_pins_are_placed_removed_and_saved() -> void:
	var setup: Array = await _open_map("", "res://levels/overworld.tscn")
	var tree: SceneTree = setup[0]
	var state: Node = setup[1]
	var page: Control = setup[3]
	await tree.process_frame
	page._move_cursor(page.world_to_map(Vector2(-10, 4)))
	_press(&"ui_accept")
	await tree.process_frame
	assert_eq(state.map_pins.size(), 1, "A pone un pin")
	assert_eq(page.pins.get_child_count(), 1)
	assert_eq(page.pins_label.text, tr("MAP_PINS").format({count = 1, max = 4}))
	for point in [Vector2(10, 4), Vector2(20, 4), Vector2(-20, 4)]:
		state.toggle_pin(point)
	assert_eq(state.toggle_pin(Vector2(0, -20)), false, "no más de cuatro")
	var cfg := ConfigFile.new()
	state.write_to(cfg)
	state.reset()
	state.read_from(cfg)
	assert_eq(state.map_pins.size(), 4, "se guardan con la partida")
	state.toggle_pin(Vector2(-10.5, 4.5))
	assert_eq(state.map_pins.size(), 3, "poner sobre uno lo quita")
	_close(setup[2])
	state.reset()


func test_zoom_follows_the_cursor() -> void:
	var setup: Array = await _open_map("", "res://levels/overworld.tscn")
	var tree: SceneTree = setup[0]
	var page: Control = setup[3]
	await tree.process_frame
	assert_eq(page.extra_hints[1][1], "MAP_HINT_ZOOM_IN")
	_press(&"item_2")
	await tree.process_frame
	assert_eq(page.canvas.scale, Vector2.ONE * 2.0, "Y acerca")
	assert_eq(page.extra_hints[1][1], "MAP_HINT_ZOOM_OUT")
	var on_screen: Vector2 = page.canvas.position + page.cursor.position * page.canvas.scale
	assert_true(Rect2(Vector2.ZERO, page.overworld.size).has_point(on_screen), "el cursor queda a la vista")
	_close(setup[2])


func test_dungeon_doors_and_room_cursor() -> void:
	var setup: Array = await _open_map("dungeon_no_bow")
	var tree: SceneTree = setup[0]
	var state: Node = setup[1]
	var page: Control = setup[3]
	state.give(Items.get_item(&"dungeon_map"))
	await tree.process_frame
	var kinds: Array = page.doors_layer.get_children().map(func(mark: MapMark) -> MapMark.Kind: return mark.kind)
	assert_true(kinds.has(MapMark.Kind.DOOR_BOSS), "la puerta del jefe")
	assert_true(kinds.has(MapMark.Kind.DOOR_OPEN), "pasos libres")
	assert_true(kinds.size() >= 8, "las puertas entre salas (%d)" % kinds.size())
	var start: Room = page.focused_room()
	assert_eq(start.display_name, page.focus_title.text, "el cursor arranca en la sala actual")
	_press(&"ui_left")
	await tree.process_frame
	assert_true(page.focused_room() != start and page.focused_room().map_cell.x < start.map_cell.x, "salta a la sala de la izquierda")
	assert_eq(page.focus_title.text, page.focused_room().display_name)
	_close(setup[2])
	state.reset()


func test_overworld_photo_is_taken_from_the_current_level() -> void:
	var setup: Array = await _open_map("", "res://levels/overworld.tscn")
	var tree: SceneTree = setup[0]
	var page: Control = setup[3]
	var map: OverworldMap = tree.current_scene.get_node(^"OverworldMap")
	assert_true(page.overworld_image.texture is ViewportTexture, "la imagen es la foto en vivo")
	assert_eq(Vector2(map.texture.get_size()), map.world_rect.size * OverworldMap.PIXELS_PER_METER)
	assert_true(map._grid_copy())
	var copy: Node3D = map.get_node(^"%GridCopy")
	var instances := 0
	for child: MultiMeshInstance3D in copy.get_children():
		instances += child.multimesh.instance_count
		assert_eq(child.layers, 1 << (OverworldMap.MAP_LAYER - 1), "solo la cámara del mapa la ve")
	assert_eq(instances, map.grid.get_used_cells().size(), "todas las celdas del GridMap")
	for child in copy.get_children():
		child.free()
	_close(setup[2])
