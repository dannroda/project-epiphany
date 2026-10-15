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
	var camera := tree.get_first_node_in_group(TopDownCamera.GROUP) as TopDownCamera
	var player := tree.get_first_node_in_group(&"player") as Node3D
	for i in 120:
		if camera == null or player == null or camera.room == null or camera.room.contains(player.global_position):
			break
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
	assert_true(page.overworld.visible and not page.cells.visible and not page.map_items.visible, "vista de overworld, sin ítems de mazmorra")
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


func _trigger(axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)


func _joy_a() -> void:
	for pressed in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = JOY_BUTTON_A
		event.pressed = pressed
		Input.parse_input_event(event)


func _press(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	var release := InputEventAction.new()
	release.action = action
	Input.parse_input_event(release)


func test_overworld_names_appear_as_zones_are_visited() -> void:
	var setup: Array = await _open_map("", "res://levels/overworld.tscn")
	var tree: SceneTree = setup[0]
	var state: Node = setup[1]
	var page: Control = setup[3]
	await tree.process_frame
	assert_eq(state.visited_zones, [&"Zone_start"] as Array[StringName], "partida nueva: solo el claro del inicio")
	var explored: Texture2D = (page.overworld_image.material as ShaderMaterial).get_shader_parameter(&"explored")
	assert_true(explored != null and explored.get_size() == Vector2(state.map_revealed.get_size()), "la foto se revela con lo descubierto del minimapa")
	assert_eq(page.subtitle.text, tr("MAP_ZONES_EXPLORED").format({done = 1, total = 14}) + " · " + tr("MAP_PORTALS_LIT").format({done = 0, total = 6}), "cuenta regiones grandes, no pantallas, y portales")
	var names := func() -> Array: return page.marks.get_children().filter(func(mark: Node) -> bool: return mark is Label).map(func(label: Label) -> String: return label.text)
	assert_eq(names.call(), [tr("PLACE_FIRST_CLEARING")], "solo el nombre de la región visitada, una vez")
	state.set_flag(&"ow_grotto_cracked_wall", true)
	state.visit_zone(page._zone_at(Vector2(-82, 14)).name)
	state.visit_zone(&"Zone_vertiente")
	page.refresh()
	await tree.process_frame
	await tree.process_frame
	assert_eq(names.call().count(tr("PLACE_FIRST_CLEARING")), 1, "varias pantallas de la región: el nombre va una sola vez")
	assert_true(tr("PLACE_HIDDEN_GROTTO") in names.call() and tr("PLACE_SPRING") in names.call(), "las cuevas visitadas llevan su nombre (%s)" % [names.call()])
	assert_true(not tr("PLACE_BOMB_CAVE") in names.call(), "la de una zona sin visitar no")
	state.visit_zone(&"Zone_pradera")
	page.refresh()
	await tree.process_frame
	await tree.process_frame
	_close(setup[2])
	state.reset()


func test_cursor_reads_what_is_missing_in_a_zone() -> void:
	var setup: Array = await _open_map("", "res://levels/overworld.tscn")
	var tree: SceneTree = setup[0]
	var state: Node = setup[1]
	var page: Control = setup[3]
	var grotto: AreaZone = page._zone_at(Vector2(-82, 14))
	state.visit_zone(grotto.name)
	page.refresh()
	await tree.process_frame
	await tree.process_frame
	page._move_cursor(page.world_to_map(grotto.bounds().get_center()))
	assert_eq(page.focus_title.text, "PLACE_FIRST_CLEARING", "la entrada de la gruta es parte de la región del Claro")
	var rows: Array = page.focus_stats.get_children().map(func(row: StatRow) -> String: return row.get_node(^"Padding/Row/Name").text + "=" + row.value_text())
	assert_true(rows.has("MAP_CHESTS=" + tr("MAP_COUNT").format({done = 0, total = 1})), "dice que falta el cofre del claro (%s)" % [rows])
	assert_true(rows.has("MAP_TABLETS_READ=" + tr("MAP_COUNT").format({done = 0, total = 4})), "y las tablillas sin leer (%s)" % [rows])
	var first_row: Node = page.focus_stats.get_child(0)
	page._move_cursor(page.world_to_map(grotto.bounds().get_center() + Vector2(0.5, 0.5)))
	await tree.process_frame
	assert_true(is_instance_valid(first_row) and first_row.get_parent() == page.focus_stats, "moverse dentro de la misma zona no rehace el panel")
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
	_press(&"item_1")
	await tree.process_frame
	assert_eq(state.map_pins.size(), 1, "X pone un pin")
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
	assert_eq(page.extra_hints[2][1], "MAP_HINT_ZOOM_IN")
	_press(&"item_2")
	await tree.process_frame
	assert_eq(page.canvas.scale, Vector2.ONE * 2.0, "Y acerca")
	assert_eq(page.extra_hints[2][1], "MAP_HINT_ZOOM_OUT")
	var on_screen: Vector2 = page.canvas.position + page.cursor.position * page.canvas.scale
	assert_true(Rect2(Vector2.ZERO, page.overworld.size).has_point(on_screen), "el cursor queda a la vista")
	_close(setup[2])


func test_dungeon_doors_and_room_cursor() -> void:
	var setup: Array = await _open_map("templo")
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


func test_floor_selector_in_a_dungeon_with_floors() -> void:
	var setup: Array = await _open_map("chullpa")
	var tree: SceneTree = setup[0]
	var state: Node = setup[1]
	var page: Control = setup[3]
	var dungeon: DungeonState = state.current_dungeon_state()
	dungeon.has_map = true
	dungeon.has_compass = true
	await tree.process_frame
	assert_true(page.floors_box.visible, "la Chullpa tiene columna de pisos")
	assert_true(page.map_items.visible, "los ítems de la mazmorra se ven")
	var shown := func(tile: String) -> bool: return page.get_node("%" + tile).modulate.a == 1.0
	assert_true(shown.call("MapItem") and shown.call("CompassItem"), "mapa y brújula, prendidos")
	assert_true(not shown.call("BossKeyItem") and not shown.call("KeysItem"), "sin llave del jefe ni llaves, apagados")
	assert_true(page.get_node(^"%MapItem/%Icon").texture != null, "con su ícono")
	dungeon.small_keys = 2
	await tree.process_frame
	assert_eq(page.get_node(^"%KeysItem/%Count").text, "2", "las llaves chicas con su cantidad")
	var buttons: Array = page.floor_buttons.get_children()
	assert_eq(buttons.map(func(button: MapFloorButton) -> String: return button.code), ["2P", "1P", "S1"], "de arriba abajo")
	assert_true(buttons[1].here and buttons[1].selected, "abre en la planta baja, donde está el player")
	assert_true(buttons[2].boss and buttons[2].chest, "con brújula, el sótano marca jefe y cofres")
	assert_true(_cell(page, "Entrada") != null, "se ven las salas de la planta baja")
	assert_eq(page.focused_room().name, &"Entrada")
	_press(&"map_floor_up")
	await tree.process_frame
	assert_eq(page.viewed_level(), 1, "LT sube un piso")
	assert_true(_cell(page, "Rellano") != null and _cell(page, "Entrada") == null, "ahora el piso alto")
	assert_eq(page.focused_room().name, &"Rellano", "el cursor queda en la misma celda")
	assert_true(page.extra_hints.any(func(hint: Array) -> bool: return hint[1] == "MAP_HINT_FLOOR"), "la barra de ayudas lo dice")
	_press(&"map_floor_up")
	await tree.process_frame
	assert_eq(page.viewed_level(), 1, "no hay más arriba")
	(page.floor_buttons.get_child(2) as MapFloorButton).pressed.emit()
	await tree.process_frame
	assert_eq(page.viewed_level(), -1, "con un clic se ve el sótano")
	for value in [0.3, 0.5, 0.7, 0.9, 1.0]:
		_trigger(JOY_AXIS_TRIGGER_LEFT, value)
		await tree.process_frame
	assert_eq(page.viewed_level(), 0, "un gatillo analógico apretado de a poco sube un solo piso")
	_trigger(JOY_AXIS_TRIGGER_LEFT, 0.0)
	_trigger(JOY_AXIS_TRIGGER_LEFT, 1.0)
	await tree.process_frame
	assert_eq(page.viewed_level(), 1, "soltarlo y volver a apretar sube otro")
	_trigger(JOY_AXIS_TRIGGER_LEFT, 0.0)
	_press(&"ui_down")
	await tree.process_frame
	assert_eq(page.viewed_level(), 0, "la cruceta abajo baja un piso")
	for value in [-0.3, -0.6, -0.9, -1.0]:
		_trigger(JOY_AXIS_LEFT_Y, value)
		await tree.process_frame
	assert_eq(page.viewed_level(), 1, "el stick izquierdo arriba sube un solo piso")
	_trigger(JOY_AXIS_LEFT_Y, 0.0)
	assert_true(page.extra_hints.any(func(hint: Array) -> bool: return hint[0] == [&"move_forward", &"move_backward"]), "la ayuda muestra arriba y abajo")
	var seen := {}
	for i in page._room_cells.size():
		seen[page.focused_room()] = true
		_press(&"ui_right")
		await tree.process_frame
	assert_eq(seen.size(), page._room_cells.size(), "izquierda y derecha recorren todas las salas del piso")
	_close(setup[2])
	state.reset()


func test_the_stick_moves_one_floor_and_one_room_per_push() -> void:
	var setup: Array = await _open_map("chullpa")
	var tree: SceneTree = setup[0]
	var page: Control = setup[3]
	(setup[1].current_dungeon_state() as DungeonState).has_map = true
	await tree.process_frame
	(page.floor_buttons.get_child(2) as MapFloorButton).pressed.emit()
	await tree.process_frame
	assert_eq(page.viewed_level(), -1)
	for value in [-0.25, -0.4, -0.55, -0.7, -0.85, -0.95, -1.0, -0.98, -1.0, -0.99]:
		_trigger(JOY_AXIS_LEFT_Y, value)
		await tree.process_frame
	assert_eq(page.viewed_level(), 0, "el stick arriba sube un solo piso aunque lleguen muchos eventos")
	_trigger(JOY_AXIS_LEFT_Y, 0.0)
	await tree.process_frame
	var first: Room = page.focused_room()
	for value in [0.25, 0.4, 0.55, 0.7, 0.85, 0.95, 1.0, 0.98, 1.0, 0.99]:
		_trigger(JOY_AXIS_LEFT_X, value)
		await tree.process_frame
	assert_eq(page._next_in_reading_order(first, 1).name, page.focused_room().name, "el stick a la derecha pasa a la sala siguiente, una sola")
	_trigger(JOY_AXIS_LEFT_X, 0.0)
	await tree.process_frame
	_trigger(JOY_AXIS_LEFT_X, 1.0)
	await tree.process_frame
	_trigger(JOY_AXIS_LEFT_X, 0.0)
	await tree.process_frame
	assert_eq(page._next_in_reading_order(page._next_in_reading_order(first, 1), 1).name, page.focused_room().name, "soltar y volver a empujar pasa otra")
	_close(setup[2])
	setup[1].reset()


func test_minimap_names_the_floor() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	state.reset()
	await tree.root.get_node(^"SaveManager").load_scenario("chullpa")
	await tree.create_timer(1.0).timeout
	var minimap: Control = tree.get_first_node_in_group(&"hud").find_child("Minimap", true, false)
	assert_true(minimap.floor_tag.visible, "en la Chullpa, el minimapa nombra el piso")
	assert_eq(minimap.floor_code.text, "1P")
	state.reset()
	await tree.root.get_node(^"SaveManager").load_scenario("pre_boss")
	await tree.create_timer(1.0).timeout
	minimap = tree.get_first_node_in_group(&"hud").find_child("Minimap", true, false)
	assert_true(not minimap.floor_tag.visible, "en el templo (un solo piso), no")
	state.reset()


func test_travel_portals_light_up_and_the_map_travels() -> void:
	var setup: Array = await _open_map("", "res://levels/overworld.tscn")
	var tree: SceneTree = setup[0]
	var state: Node = setup[1]
	var stack: Node = setup[2]
	_close(stack)
	var portals := TravelPortal.all(tree)
	assert_eq(portals.size(), 6, "seis portales")
	assert_true(portals.all(func(portal: TravelPortal) -> bool: return not portal.lit), "arrancan apagados")
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	var space := player.get_world_3d().direct_space_state
	for portal in portals:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(portal.global_position + Vector3.UP * 5.0, portal.global_position + Vector3.DOWN * 5.0, 1))
		assert_true(not hit.is_empty() and absf(hit.position.y - portal.global_position.y) < 0.3, "%s apoyado en el piso" % portal.name)
		var near := tree.current_scene.find_children("*", "Interactable", true, false).filter(func(other: Interactable) -> bool:
			return not portal.is_ancestor_of(other) and other.global_position.distance_to(portal.global_position) < 3.0)
		assert_eq(near.size(), 0, "%s sin otro interactuable al lado (E lee eso en vez de abrir el mapa)" % portal.name)
	var claro: TravelPortal = tree.current_scene.get_node(^"TravelPortals/PortalClaro")
	player.global_position = claro.global_position + Vector3.UP * 0.2
	for i in 6:
		await tree.physics_frame
	assert_true(claro.lit, "al pasar se prende")
	assert_eq(state.get_flag(&"ow_portal_claro"), true, "y queda guardado")
	claro.interactable.interact(player)
	await tree.process_frame
	assert_true(stack.top() is UiScreen and stack.top().get(&"pages") != null and stack.top().current == 2, "parado en él, interactuar abre el Mapa")
	var page: Control = stack.top().pages.get_node(^"Mapa")
	state.set_flag(&"ow_portal_necropolis", true)
	state.visit_zone(&"Zone_necropolis")
	page.refresh()
	await tree.process_frame
	assert_eq(page.marks.get_children().filter(func(mark: Node) -> bool: return mark is MapMark and mark.kind == MapMark.Kind.PORTAL).size(), 2, "los dos prendidos en el mapa")
	page._move_cursor(page._portal_point(claro) + Vector2(4, 3))
	assert_eq(page.focused_portal(), claro, "cerca de un portal el cursor se engancha")
	assert_eq(page.cursor.position, page._portal_point(claro))
	assert_true(page.portal_title.visible and not page.can_travel(), "el del claro: ya está en esa región")
	assert_eq(page.focus_text.text, "MAP_TRAVEL_HERE")
	var necropolis: TravelPortal = tree.current_scene.get_node(^"TravelPortals/PortalNecropolis")
	page._move_cursor(page._portal_point(necropolis) - Vector2(5, 0))
	assert_eq(page.focused_portal(), necropolis)
	assert_true(page.can_travel() and page.travel_button.visible, "a la Necrópolis se puede viajar")
	assert_eq(page.portal_name.text, tr("MAP_PORTAL").format({name = tr("PLACE_NECROPOLIS")}))
	assert_true(page.extra_hints.any(func(hint: Array) -> bool: return hint == [&"ui_accept", "MAP_HINT_TRAVEL"]), "la barra de ayudas dice A Viajar")
	_joy_a()
	await tree.process_frame
	await tree.process_frame
	var dialog := stack.top() as ConfirmDialog
	assert_true(dialog != null, "pregunta antes de viajar")
	if dialog == null:
		_close(stack)
		return
	assert_true(dialog.yes.has_focus(), "arranca en Viajar (A confirma, como el mockup)")
	_joy_a()
	await tree.process_frame
	await tree.process_frame
	assert_eq(tree.root.get_node(^"MenuStack").get_children().filter(func(screen: Node) -> bool: return screen is ConfirmDialog).size(), 0, "A con el control confirma; el mapa tapado no abre otra pregunta")
	var saves: Node = tree.root.get_node(^"SaveManager")
	var until := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < until and (not tree.root.get_node(^"SceneFlow").traveling or tree.paused):
		await tree.process_frame
	while tree.root.get_node(^"SceneFlow").traveling:
		await tree.process_frame
	player = tree.get_first_node_in_group(&"player") as PlayerCharacter
	assert_eq(state.spawn_point, &"portal_necropolis", "viajó al portal de la Necrópolis")
	assert_true(Vector2(player.global_position.x, player.global_position.z).distance_to(Vector2(32, -2)) < 2.5, "y aparece ahí (%s)" % player.global_position.snappedf(0.1))
	assert_true(not stack.is_open(), "con el menú cerrado")
	state.reset()


func test_renaming_a_zone_keeps_it_visited() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	state.reset()
	tree.change_scene_to_file("res://levels/overworld.tscn")
	await tree.scene_changed
	await tree.physics_frame
	var risk: AreaZone = tree.current_scene.get_node(^"Zone_risco")
	assert_eq(risk.is_visited(), false)
	state.visit_zone(&"Zone_risco")
	risk.name = &"Zone_risco_renombrada"
	assert_eq(risk.is_visited(), true, "la clave es el id, no el nombre del nodo")
	assert_true(tree.current_scene.find_children("Zone_*", "AreaZone", false, false).all(func(zone: AreaZone) -> bool: return not zone.id.is_empty()), "todas las zonas del overworld tienen id")
	state.reset()


func test_the_overworld_cursor_stays_put_when_the_map_resizes() -> void:
	var setup: Array = await _open_map("", "res://levels/overworld.tscn")
	var tree: SceneTree = setup[0]
	var state: Node = setup[1]
	var page: Control = setup[3]
	var spot: Vector2 = page.map_to_world(page._cursor_point) + Vector2(12.0, -8.0)
	page._move_cursor(page.world_to_map(spot))
	var size: Vector2 = page.overworld_image.size
	page.overworld_image.offset_right -= 60.0
	await tree.process_frame
	assert_true(page.overworld_image.size != size, "el mapa se achica (el panel de al lado creció)")
	assert_true(page.map_to_world(page._cursor_point).distance_to(spot) < 0.1, "el cursor queda en el mismo lugar del mundo, no vuelve al player")
	page.overworld_image.offset_right += 60.0
	_close(setup[2])
	state.reset()
