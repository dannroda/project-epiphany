extends "res://tests/test_case.gd"


func _load(scenario := "", level := "") -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	var settings: Node = tree.root.get_node(^"Settings")
	settings.path = settings_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))
	settings.load_settings()
	settings.set_value(&"language", "es")
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
	DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))
	settings.load_settings()
	settings.set_value(&"language", "es")
	state.reset()


func test_the_floor_tag_sits_above_the_minimap() -> void:
	var setup: Array = await _load("chullpa")
	var minimap: Control = setup[3]
	var tag: Control = minimap.get_node(^"%FloorTag")
	assert_true(tag.visible, "en una mazmorra de varios pisos se ve el piso")
	assert_true(tag.get_global_rect().end.y <= minimap.get_global_rect().position.y, "arriba del minimapa, sin taparlo (%s / %s)" % [tag.get_global_rect(), minimap.get_global_rect()])
	(setup[1] as Node).reset()


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


func test_overworld_stays_revealed_where_the_player_went_and_saves_it() -> void:
	var setup: Array = await _load("", "res://levels/overworld.tscn")
	var tree: SceneTree = setup[0]
	var state: Node = setup[1]
	var minimap: Control = setup[3]
	var player := tree.get_first_node_in_group(&"player") as Node3D
	var rect: Rect2 = minimap._map.world_rect
	var seen := func(point: Vector3) -> float:
		return state.map_revealed.get_pixelv(Vector2i(Vector2(point.x, point.z) - rect.position)).r
	var start := player.global_position
	var far := start + Vector3(0, 0, -20)
	assert_true(seen.call(start) > 0.9, "donde está el player se ve")
	assert_true(seen.call(far) < 0.1, "lejos todavía no")
	player.global_position = far
	for i in 3:
		await tree.process_frame
	assert_true(seen.call(far) > 0.9, "al llegar se descubre")
	assert_true(seen.call(start) > 0.9, "y lo de antes queda descubierto")
	var cfg := ConfigFile.new()
	state.write_to(cfg)
	state.reset()
	assert_true(state.map_revealed == null or seen.call(start) < 0.1, "una partida nueva empieza sin descubrir")
	state.read_from(cfg)
	assert_true(seen.call(far) > 0.9 and seen.call(start) > 0.9, "se guarda con la partida")
	state.reset()


func test_fades_while_a_player_is_under_it() -> void:
	var setup: Array = await _load("test_rooms")
	var tree: SceneTree = setup[0]
	var minimap: Control = setup[3]
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	await tree.create_timer(1.0).timeout
	var start := player.global_position
	var camera := tree.root.get_viewport().get_camera_3d()
	var center := minimap.get_global_rect().get_center()
	var under := start
	for dx in range(-20, 21):
		for dz in range(-14, 15):
			var point := start + Vector3(dx * 0.5, 0, dz * 0.5)
			if camera.unproject_position(point).distance_to(center) < camera.unproject_position(under).distance_to(center):
				under = point
	assert_true(minimap.visible and minimap.get_global_rect().has_point(camera.unproject_position(under)), "se ve y hay piso debajo")
	assert_eq(minimap.covers_a_player(), false, "en la entrada no tapa al player")
	player.global_position = under
	player.velocity = Vector3.ZERO
	await tree.create_timer(0.6).timeout
	assert_true(minimap.covers_a_player(), "con el player debajo lo tapa")
	assert_true(minimap.modulate.a < 0.5, "y se transparenta (%.2f)" % minimap.modulate.a)
	player.global_position = start
	await tree.create_timer(0.6).timeout
	assert_true(minimap.modulate.a > 0.9, "al salir vuelve (%.2f)" % minimap.modulate.a)
	setup[1].reset()


func test_dungeon_doors_are_read_once_and_follow_their_state() -> void:
	var setup: Array = await _load("test_rooms")
	var tree: SceneTree = setup[0]
	var minimap: Control = setup[3]
	var MapData: GDScript = minimap.MapData
	assert_eq(minimap._doors.size(), MapData.doors(tree).size(), "las mismas puertas que lee la pestaña Mapa")
	var door: Door = minimap._door_nodes.filter(func(each: Door) -> bool: return not each.is_open).front()
	var at: Array = minimap._doors.filter(func(mark: Array) -> bool: return mark[0] == door.global_position).front()
	assert_true(at[1] != MapMark.Kind.DOOR_OPEN, "una puerta cerrada")
	door.open()
	await tree.process_frame
	at = minimap._doors.filter(func(mark: Array) -> bool: return mark[0] == door.global_position).front()
	assert_eq(at[1], MapMark.Kind.DOOR_OPEN, "al abrirse, el minimapa lo muestra en el cuadro siguiente")
	setup[1].reset()
