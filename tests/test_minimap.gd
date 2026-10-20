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
	var setup: Array = await _load("", "res://levels/templo.tscn")
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


## 11.12: una sala de dos celdas se ve entera y la actual queda centrada aunque ocupe varias.
func test_a_room_of_two_cells_is_drawn_whole() -> void:
	var setup: Array = await _load("test_rooms")
	var tree: SceneTree = setup[0]
	var minimap: Control = setup[3]
	setup[1].current_dungeon_state().has_map = true
	var rooms: Array = tree.get_nodes_in_group(Room.GROUP)
	var by_name := {}
	for room: Room in rooms:
		by_name[room.name] = room
	var here: Room = by_name[&"RoomA"]
	var wide: Room = by_name[&"RoomB"]
	var single: Rect2 = minimap.room_rect(here, here)
	wide.map_size = Vector2i(2, 1)
	assert_true(minimap.rooms_around().has(wide), "la vecina grande se ve")
	var drawn: Rect2 = minimap.room_rect(wide, here)
	assert_eq(drawn.size, Vector2(2 * minimap.PITCH.x - (minimap.PITCH.x - minimap.CELL.x), minimap.CELL.y), "dos columnas")
	assert_eq(drawn.position.x, single.position.x, "arranca sobre la sala actual")
	assert_eq(minimap.room_rect(here, here), single, "la actual no se mueve")
	var centered: Rect2 = minimap.room_rect(wide, wide)
	assert_eq(centered.get_center(), single.get_center(), "parado en la grande, queda centrada")
	assert_true(minimap.room_rect(here, wide).get_center().x < single.get_center().x, "y la de abajo se corre a su columna")
	wide.map_size = Vector2i.ONE
	setup[1].reset()


## Todo lo que se camina (el GridMap se copia aparte) y el agua salen en la foto (11.148: la quebrada salía como abismo).
func test_the_photo_shows_the_ground_and_the_water() -> void:
	var setup: Array = await _load("", "res://levels/overworld.tscn")
	var tree: SceneTree = setup[0]
	var missing: Array[String] = []
	var sources: Array[Node] = tree.get_nodes_in_group(&"navmesh_source").filter(func(n: Node) -> bool: return not n is GridMap)
	sources.append_array(tree.current_scene.find_children("*Water*", "VisualInstance3D", false, false))
	for source in sources:
		var visuals: Array[Node] = source.find_children("*", "VisualInstance3D", true, false)
		if source is VisualInstance3D:
			visuals.append(source)
		for visual: VisualInstance3D in visuals:
			if visual.visible and not visual.get_layer_mask_value(OverworldMap.MAP_LAYER):
				missing.append(String(tree.current_scene.get_path_to(visual)))
	assert_true(not sources.is_empty(), "hay suelo y agua")
	assert_eq(missing.slice(0, 5), [], "%d piezas del suelo o del agua no salen en la foto" % missing.size())
	setup[1].reset()


## Lo que cambia y queda (el puente que sube) aparece en el minimapa: la foto se vuelve a sacar cuando terminó de moverse.
func test_a_persistent_change_retakes_the_photo() -> void:
	var setup: Array = await _load("", "res://levels/overworld.tscn")
	var tree: SceneTree = setup[0]
	var map := tree.current_scene.find_children("*", "OverworldMap", true, false)[0] as OverworldMap
	var bridge := tree.current_scene.get_node(^"RavineBridge") as Node3D
	assert_true(bridge.find_children("*", "VisualInstance3D", true, false).all(func(v: VisualInstance3D) -> bool: return v.get_layer_mask_value(OverworldMap.MAP_LAYER)), "el puente sale en la foto")
	var taken := [false]
	map.photo_requested.connect(func() -> void: taken[0] = true)
	setup[1].set_flag(&"ow_sandals_chest", true)
	await tree.create_timer(OverworldMap.RETAKE_DELAY * 1.5).timeout
	assert_true(not taken[0], "15.13: abrir un cofre no cambia el mapa, no saca otra foto")
	assert_true(map.is_layout_flag(&"ow_ravine_bridge_eye") and map.is_layout_flag(&"ow_secret_ravine_wall"), "el ojo del puente y el muro roto sí")
	setup[1].set_flag(&"ow_ravine_bridge_eye", true)
	await tree.create_timer(OverworldMap.RETAKE_DELAY * 0.5).timeout
	assert_true(not taken[0], "espera a que termine de moverse")
	await tree.create_timer(OverworldMap.RETAKE_DELAY).timeout
	assert_true(taken[0], "y saca la foto de nuevo")
	setup[1].reset()


## 11.86: lo descubierto lo pinta el mundo (OverworldMap), no el minimapa: sin HUD también se registra.
func test_the_world_reveals_the_map_without_a_hud() -> void:
	var setup: Array = await _load("", "res://levels/overworld.tscn")
	var tree: SceneTree = setup[0]
	var state: Node = setup[1]
	var map := tree.current_scene.find_children("*", "OverworldMap", true, false)[0] as OverworldMap
	for hud in tree.get_nodes_in_group(&"hud"):
		hud.queue_free()
	await tree.process_frame
	var player := tree.get_first_node_in_group(&"player") as Node3D
	var far := player.global_position + Vector3(0, 0, -20)
	var seen := func(point: Vector3) -> float:
		return state.map_revealed.get_pixelv(Vector2i(Vector2(point.x, point.z) - map.world_rect.position)).r
	assert_true(seen.call(far) < 0.1, "lejos todavía no")
	player.global_position = far
	for i in 3:
		await tree.physics_frame
	assert_true(seen.call(far) > 0.9, "sin HUD, al llegar se descubre")
	state.reset()


func test_the_explored_map_survives_a_moved_rect_other_maps_and_old_saves() -> void:
	var state: Node = (Engine.get_main_loop() as SceneTree).root.get_node(^"GameState")
	state.reset()
	state.ensure_map_revealed(&"a", Rect2(0, 0, 10, 10))
	state.map_revealed.set_pixel(5, 5, Color.WHITE)
	state.ensure_map_revealed(&"a", Rect2(-2, 0, 20, 10))
	assert_eq(state.map_revealed.get_size(), Vector2i(20, 10), "el mapa creció")
	assert_true(state.map_revealed.get_pixel(7, 5).r > 0.9, "y lo descubierto sigue en el mismo lugar del mundo")
	state.ensure_map_revealed(&"b", Rect2(0, 0, 4, 4))
	assert_true(state.map_revealed.get_pixel(1, 1).r < 0.1, "otro mapa tiene lo suyo")
	state.ensure_map_revealed(&"a", Rect2(-2, 0, 20, 10))
	assert_true(state.map_revealed.get_pixel(7, 5).r > 0.9, "y no borra el primero")
	var cfg := ConfigFile.new()
	state.write_to(cfg)
	state.reset()
	state.read_from(cfg)
	state.ensure_map_revealed(&"a", Rect2(-2, 0, 20, 10))
	assert_true(state.map_revealed.get_pixel(7, 5).r > 0.9, "se guarda con su origen")
	var legacy := Image.create_empty(200, 96, false, Image.FORMAT_L8)
	legacy.set_pixel(10, 10, Color.WHITE)
	var old := ConfigFile.new()
	old.set_value("map", "revealed_size", Vector2i(200, 96))
	old.set_value("map", "revealed", legacy.get_data().compress(FileAccess.COMPRESSION_ZSTD))
	state.read_from(old)
	state.ensure_map_revealed(&"overworld", Rect2(-101, -49, 200, 96))
	assert_true(state.map_revealed.get_pixel(10, 10).r > 0.9, "las partidas de antes son del overworld")
	state.reset()
