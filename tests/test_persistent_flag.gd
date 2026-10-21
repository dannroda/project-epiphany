extends "res://tests/test_case.gd"

const LEVEL := "res://levels/test/test.tscn"
const SLOT := 9


func _load_level(tree: SceneTree) -> void:
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	for i in 3:
		await tree.physics_frame


func _finish_text(tree: SceneTree) -> void:
	var stack: Node = tree.root.get_node(^"MenuStack")
	while stack.is_open():
		await tree.create_timer(0.3).timeout
		var top: Node = stack.top()
		if top is TextBox:
			top.advance()
		elif top and top.get(&"text_box"):
			top.text_box.advance()


func test_warnings_for_bad_flags() -> void:
	assert_eq(PersistentFlag.warnings_for(&"ow_test_chest", false).size(), 0, "registrado y con prefijo")
	assert_eq(PersistentFlag.warnings_for(&"ow_test_chets", false).size(), 1, "mal escrito: no está registrado")
	assert_eq(PersistentFlag.warnings_for(&"test_chest", false).size(), 1, "sin registrar")
	var level := Node3D.new()
	var dungeon := Dungeon.new()
	dungeon.id = &"ch"
	level.add_child(dungeon)
	dungeon.owner = level
	var inside: Chest = preload("res://src/world/props/chest.tscn").instantiate()
	level.add_child(inside)
	inside.owner = level
	inside.flag = &"ow_test_chest"
	assert_eq(inside._get_configuration_warnings().size(), 1, "en la Chullpa un flag ow_ no sigue la convención")
	inside.flag = &"ch_feather_chest"
	assert_eq(inside._get_configuration_warnings().size(), 0, "ch_ sí")
	level.free()
	assert_eq(PersistentFlag.warnings_for(&"", true).size(), 0, "opcional y vacío: sin advertencia")
	var chest: Chest = preload("res://src/world/props/chest.tscn").instantiate()
	chest.flag = &"ow_test_chets"
	assert_eq(chest._get_configuration_warnings().size(), 1, "el cofre muestra la advertencia")
	chest.free()


func test_a_flag_freed_before_its_first_announce_is_left_alone() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	for i in 20:
		var node := PersistentFlag.new()
		node.flag = &"ow_test_chest"
		tree.root.add_child(node)
		node.free()
		var other := HitFlash.new()
		tree.root.add_child(other)
		other.queue_free()
	await tree.process_frame
	await tree.process_frame
	assert_eq(tree.root.get_children().filter(func(n: Node) -> bool: return n is PersistentFlag).size(), 0, "el anuncio diferido no corre sobre un nodo liberado")


func test_world_state_survives_save_reload_and_load() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	var saves: Node = tree.root.get_node(^"SaveManager")
	state.reset()
	await _load_level(tree)
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	var chest: Chest = tree.current_scene.get_node(^"Chest")
	chest.interactable.interact(player)
	await _finish_text(tree)
	tree.current_scene.get_node(^"TabletHint").interactable.interact(player)
	await _finish_text(tree)
	assert_eq(saves.save_game(SLOT), OK)

	await _load_level(tree)
	assert_eq(await saves.load_game(SLOT), OK)
	await tree.process_frame
	chest = tree.current_scene.get_node(^"Chest")
	assert_eq(chest.interactable.enabled, false, "cofre abierto tras recargar y cargar")
	assert_true(chest.lid.rotation_degrees.x < -90.0)
	assert_eq(tree.current_scene.get_node(^"TabletHint").is_read(), true, "tablilla leída")
	assert_eq(state.inventory.has(&"bomb_bag"), true)

	state.reset()
	await tree.process_frame
	assert_eq(chest.interactable.enabled, true, "cargar una partida sin el flag cierra el cofre en la escena")
	assert_true(is_zero_approx(chest.lid.rotation_degrees.x))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saves.slot_path(SLOT)))
	state.reset()


func test_scenario_with_flags_set_by_hand() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	var cfg := ConfigFile.new()
	assert_eq(SaveCodec.read("res://debug/scenarios/test_flags.cfg", cfg), OK)
	state.read_from(cfg)
	await _load_level(tree)
	assert_eq(tree.current_scene.get_node(^"Chest").interactable.enabled, false, "el cofre arranca abierto")
	assert_eq(tree.current_scene.get_node(^"TabletHint").is_read(), true)
	assert_eq(state.item_buttons[0], &"bomb_bag")
	state.reset()
