extends "res://tests/test_case.gd"


func _load(tree: SceneTree) -> void:
	var settings: Node = tree.root.get_node(^"Settings")
	settings.path = settings_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))
	settings.load_settings()
	settings.set_value(&"language", "es")
	tree.root.get_node(^"GameState").reset()
	tree.change_scene_to_file("res://levels/overworld.tscn")
	await tree.scene_changed
	for i in 6:
		await tree.process_frame


func test_the_grotto_stays_hidden_until_its_wall_breaks() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	await _load(tree)
	var scene := tree.current_scene
	var veil: ZoneVeil = scene.get_node(^"Zone_gruta/ZoneVeil")
	var wall: CrackedWall = scene.get_node(^"GrottoCrackedWall")
	var minimap: Control = tree.get_first_node_in_group(&"hud").get_node(^"%Minimap")
	var rect: Rect2 = minimap._map.world_rect
	var seen := func(x: float, z: float) -> float:
		return state.map_revealed.get_pixelv(Vector2i(Vector2(x, z) - rect.position)).r
	assert_true(veil.visible and veil.covers(Vector2(-24, 16)), "la gruta arranca tapada")
	assert_true(scene.get_node(^"Zone_santuario/ZoneVeil").visible, "el santuario también")
	assert_true(veil.covers(Vector2(-12, 12)) and veil.covers(Vector2(-24, 8)), "tapa también las paredes que la rodean")
	assert_true(not veil.covers(Vector2(-10.8, 12)) and not veil.covers(Vector2(-24, 6.8)), "hasta su cara de este lado")
	assert_true(absf(veil.get_aabb().end.y * veil.global_basis.get_scale().y + veil.global_position.y - 2.62) < 0.05, "a ras de la tapa del muro")
	var before := ConfigFile.new()
	state.write_to(before)

	var player := tree.get_first_node_in_group(&"player") as Node3D
	player.global_position = Vector3(-9, player.global_position.y, 16)
	for i in 3:
		await tree.process_frame
	assert_true(seen.call(-9.0, 16.0) > 0.9, "de este lado de la pared se descubre")
	assert_true(seen.call(-16.0, 16.0) < 0.1, "el minimapa no ve a través de la pared")

	var blast := DamageInfo.new()
	blast.element = &"explosive"
	wall._on_hit(blast)
	await tree.process_frame
	assert_true(veil.is_revealing(), "al romperla se va descubriendo")
	assert_eq(player.process_mode, Node.PROCESS_MODE_INHERIT, "sin frenar al jugador")
	assert_true(not tree.paused, "ni pausar el juego")
	await tree.create_timer(veil.reveal_time + 0.3).timeout
	assert_true(not veil.visible, "terminada, la gruta se ve")
	assert_true(seen.call(-16.0, 16.0) > 0.9, "y el minimapa la descubre")

	var after := ConfigFile.new()
	state.write_to(after)
	state.read_from(before)
	await tree.process_frame
	await tree.process_frame
	assert_true(veil.visible, "una partida con la pared entera la vuelve a tapar")
	state.read_from(after)
	await tree.process_frame
	await tree.process_frame
	assert_true(not veil.visible, "con la pared rota queda a la vista")
	state.reset()


func test_entering_the_zone_lifts_it() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	await _load(tree)
	var veil: ZoneVeil = tree.current_scene.get_node(^"Zone_gruta/ZoneVeil")
	var player := tree.get_first_node_in_group(&"player") as Node3D
	player.global_position = Vector3(-24, player.global_position.y, 16)
	for i in 4:
		await tree.physics_frame
	assert_true(not veil.visible, "estando adentro no tapa nada")
	tree.root.get_node(^"GameState").reset()
