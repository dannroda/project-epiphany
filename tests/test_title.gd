extends "res://tests/test_case.gd"

const TITLE := "res://src/ui/title/title_screen.tscn"
const SLOT := 9


func test_new_game_quit_to_title_and_continue() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	var saves: Node = tree.root.get_node(^"SaveManager")
	state.reset()
	assert_eq(ProjectSettings.get_setting("application/run/main_scene"), TITLE, "el juego arranca en el título")
	tree.change_scene_to_file(TITLE)
	await tree.scene_changed
	await tree.process_frame
	var title := tree.current_scene
	for item in ["Continue", "Load", "NewGame", "Options", "Quit"]:
		assert_true((title.get_node("%" + item) as Button).theme_type_variation == &"MenuItem", item)
	assert_eq(title.get_node(^"%DebugScenarios").visible, OS.is_debug_build(), "cargar escenario solo en debug")
	assert_true(tree.root.gui_get_focus_owner() is Button, "una opción tiene el foco (gamepad y teclado)")

	assert_eq(await tree.root.get_node(^"SceneFlow").new_game(), OK)
	assert_eq(tree.current_scene.scene_file_path, "res://levels/overworld.tscn", "nueva partida: overworld")
	var player := tree.get_first_node_in_group(&"player") as Node3D
	assert_true(player.global_position.distance_to(Vector3(-48, 0, 16)) < 0.6, "en el claro del inicio")
	assert_eq(state.inventory.has(&"sword_basic"), true, "con el equipo inicial")
	state.give(Items.get_item(&"bomb_bag"))
	assert_eq(saves.save_game(SLOT), OK)

	await tree.root.get_node(^"SceneFlow").quit_to_title()
	assert_eq(tree.current_scene.scene_file_path, TITLE, "salir al título")
	assert_eq(tree.paused, false)
	state.reset()
	assert_eq(saves.has_save(SLOT), true)
	assert_eq(await saves.load_game(SLOT), OK)
	assert_eq(tree.current_scene.scene_file_path, "res://levels/overworld.tscn", "continuar vuelve a la partida")
	assert_eq(state.inventory.has(&"bomb_bag"), true, "con lo que tenía")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saves.slot_path(SLOT)))
	state.reset()


func test_loading_from_the_title_fades_back_in() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var saves: Node = tree.root.get_node(^"SaveManager")
	var fader: Node = tree.root.get_node(^"SceneFlow")
	saves.save_dir = saves_dir
	await tree.root.get_node(^"SceneFlow").new_game(1)
	tree.change_scene_to_file(TITLE)
	await tree.scene_changed
	await tree.process_frame
	var screen: FileSelect = tree.current_scene.open_file_select(FileSelect.Mode.PLAY)
	await tree.process_frame
	screen.chosen.emit(1, false)
	await tree.scene_changed
	await tree.create_timer(1.0).timeout
	assert_eq(tree.current_scene.scene_file_path, "res://levels/overworld.tscn", "cargó la partida")
	assert_true(fader._rect.color.a < 0.01, "el fundido vuelve a transparente (alpha %.2f)" % fader._rect.color.a)
	saves.delete_slot(0)
	saves.delete_slot(1)
	tree.root.get_node(^"GameState").reset()


func test_sideways_keeps_the_focus_on_the_menu() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	tree.change_scene_to_file(TITLE)
	await tree.scene_changed
	await tree.process_frame
	var title := tree.current_scene
	for item in ["Continue", "Load", "NewGame", "Options", "Quit"]:
		var button := title.get_node("%" + item) as Button
		for side in [SIDE_LEFT, SIDE_RIGHT]:
			var to := button.find_valid_focus_neighbor(side)
			assert_true(to == null or to == button, "%s no pierde el foco hacia los costados" % item)
	var disabled := (title.get_node(^"%Load") as Button).disabled
	assert_eq((title.get_node(^"%Load") as Button).focus_mode == Control.FOCUS_NONE, disabled, "una opción deshabilitada no toma el foco")
