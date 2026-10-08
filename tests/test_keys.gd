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
