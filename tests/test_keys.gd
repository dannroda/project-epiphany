extends "res://tests/test_case.gd"


func _load(tree: SceneTree, path: String) -> void:
	tree.change_scene_to_file(path)
	await tree.scene_changed
	for i in 3:
		await tree.physics_frame


func test_key_counter_in_dungeon() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	state.reset()
	await _load(tree, "res://levels/test_rooms.tscn")
	assert_eq(state.current_dungeon, &"test_rooms", "la escena de la mazmorra setea current_dungeon")
	var hud: Node = tree.current_scene.get_node(^"HUD")
	assert_eq(hud.keys.visible, true, "en mazmorra se ven las llaves")
	assert_eq(hud.small_key_count.text, "×0")
	assert_true(hud.boss_key.modulate.a < 0.5, "sin llave del jefe, atenuada")
	state.give(Items.get_item(&"small_key"))
	state.give(Items.get_item(&"small_key"))
	assert_eq(hud.small_key_count.text, "×2", "juntar dos llaves")
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	tree.current_scene.get_node(^"LockedBC").interactable.interact(player)
	assert_eq(hud.small_key_count.text, "×1", "abrir una puerta baja el contador a 1")
	state.give(Items.get_item(&"boss_key"))
	assert_eq(hud.boss_key.modulate.a, 1.0, "con la llave del jefe, encendida")

	await _load(tree, "res://levels/test.tscn")
	assert_eq(state.current_dungeon, &"", "al salir de la mazmorra vuelve a vacío")
	hud = tree.current_scene.get_node(^"HUD")
	assert_eq(hud.keys.visible, false, "fuera de la mazmorra el contador no se ve")
	state.reset()


func test_four_boss_key_pieces_make_the_boss_key() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	state.reset()
	await _load(tree, "res://levels/test_rooms.tscn")
	var hud: Node = tree.current_scene.get_node(^"HUD")
	var piece := Items.get_item(&"boss_key_piece")
	assert_true(not hud.boss_key_pieces.visible, "sin piezas no se ve el contador")
	for count in range(1, 4):
		state.give(piece)
		assert_eq(load("res://src/ui/item_get/item_get.gd").cue_for(piece), StringName("boss_key_piece_%d" % count), "el texto cuenta las piezas")
		assert_eq(hud.boss_key_pieces.text, "%d/4" % count)
		assert_true(not state.current_dungeon_state().has_boss_key, "con %d todavía no hay llave" % count)
	state.give(piece)
	assert_true(state.current_dungeon_state().has_boss_key, "la cuarta arma la llave del jefe")
	assert_eq(load("res://src/ui/item_get/item_get.gd").cue_for(piece), &"boss_key_piece_full")
	assert_true(not hud.boss_key_pieces.visible and hud.boss_key.modulate.a == 1.0, "y el HUD muestra la llave")
	var cfg := ConfigFile.new()
	state.write_to(cfg)
	state.reset()
	state.read_from(cfg)
	assert_eq(state.dungeons[&"test_rooms"].boss_key_pieces, 4, "las piezas se guardan")
	state.reset()
