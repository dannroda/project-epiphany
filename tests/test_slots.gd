extends "res://tests/test_case.gd"


var tree: SceneTree
var saves: Node
var state: Node


func _setup() -> void:
	tree = Engine.get_main_loop() as SceneTree
	saves = tree.root.get_node(^"SaveManager")
	state = tree.root.get_node(^"GameState")
	saves.save_dir = saves_dir
	for slot in 4:
		saves.delete_slot(slot)
	state.reset()


func _teardown() -> void:
	for slot in 4:
		saves.delete_slot(slot)
	saves.save_dir = saves_dir
	saves.current_slot = 1
	state.reset()


func test_two_slots_do_not_overwrite_each_other() -> void:
	await _setup()
	assert_eq(await tree.root.get_node(^"SceneFlow").new_game(1), OK)
	assert_eq(saves.has_save(1), true, "nueva partida guarda enseguida en su ranura")
	state.give(Items.get_item(&"bomb_bag"))
	saves.save_game()
	assert_eq(await tree.root.get_node(^"SceneFlow").new_game(2), OK)
	assert_eq(state.inventory.has(&"bomb_bag"), false, "la ranura 2 arranca de cero")
	saves.save_game()
	assert_true(&"bomb_bag" in saves.slot_summary(1).items, "la ranura 1 conserva las bombas")
	assert_eq(&"bomb_bag" in saves.slot_summary(2).items, false, "y la 2 no las tiene")
	assert_eq(await saves.load_game(1), OK)
	assert_eq(saves.current_slot, 1, "cargar elige la ranura")
	assert_eq(state.inventory.has(&"bomb_bag"), true)
	assert_eq(saves.latest_slot(), 2, "la más reciente")
	assert_eq(saves.slot_summary(1).location, "PLACE_FIRST_CLEARING", "guarda la ubicación")
	_teardown()


func test_autosave_goes_to_the_auto_slot_and_remembers_its_game() -> void:
	await _setup()
	await tree.root.get_node(^"SceneFlow").new_game(2)
	state.give(Items.get_item(&"bomb_bag"))
	saves.autosave()
	assert_true(&"bomb_bag" in saves.slot_summary(saves.AUTO_SLOT).items, "el autosave va a la ranura Auto")
	assert_eq(&"bomb_bag" in saves.slot_summary(2).items, false, "la del jugador no cambia hasta guardar a mano")
	assert_eq(saves.slot_summary(saves.AUTO_SLOT).origin, 2, "y sabe de qué partida viene")
	state.reset()
	saves.current_slot = 3
	assert_eq(await saves.load_game(saves.AUTO_SLOT), OK)
	assert_eq(saves.current_slot, 2, "cargar la Auto vuelve a la partida de origen")
	saves.save_game()
	assert_true(&"bomb_bag" in saves.slot_summary(2).items, "y Guardar va a esa ranura")
	assert_eq(saves.has_save(3), false)
	_teardown()


func test_a_slot_with_only_its_backup_is_not_empty() -> void:
	await _setup()
	await tree.root.get_node(^"SceneFlow").new_game(1)
	saves.save_game()
	DirAccess.rename_absolute(saves.slot_path(1), saves.slot_path(1) + ".bak")
	assert_eq(saves.has_save(1), true, "con solo la copia de respaldo la ranura no aparece vacía")
	assert_true(not saves.slot_summary(1).is_empty(), "y la pantalla de ranuras la muestra")
	assert_eq(saves.copy_slot(1, 3), OK, "se puede copiar")
	assert_eq(saves.has_save(3), true)
	assert_eq(await saves.load_game(1), OK, "y cargar")
	_teardown()


func test_a_save_from_a_newer_version_is_refused() -> void:
	await _setup()
	var cfg := ConfigFile.new()
	cfg.set_value("player", "max_health", 40)
	cfg.set_value("meta", "version", SaveCodec.VERSION + 1)
	cfg.save(saves.slot_path(2))
	assert_eq(await saves.load_game(2), ERR_FILE_UNRECOGNIZED, "no carga una partida de un juego más nuevo")
	assert_eq(saves.current_slot, 1, "y no cambia de ranura")
	assert_eq(state.max_health, GameState.NEW_GAME_MAX_HEALTH, "ni la aplica")
	_teardown()


func test_a_cut_save_falls_back_to_the_backup() -> void:
	await _setup()
	await tree.root.get_node(^"SceneFlow").new_game(1)
	state.give(Items.get_item(&"bomb_bag"))
	saves.save_game()
	var file := FileAccess.open(saves.slot_path(1), FileAccess.WRITE)
	file.store_string("[player]\nmax_hea")
	file.close()
	state.reset()
	assert_eq(await saves.load_game(1), OK, "un guardado cortado no rompe la partida")
	assert_eq(state.max_health, 12, "se usó la copia de respaldo")
	_teardown()


func test_copy_and_delete() -> void:
	await _setup()
	await tree.root.get_node(^"SceneFlow").new_game(1)
	assert_eq(saves.copy_slot(1, 3), OK)
	assert_eq(saves.slot_summary(3).location, saves.slot_summary(1).location, "copiar duplica la partida")
	saves.delete_slot(3)
	assert_eq(saves.has_save(3), false, "borrar la deja vacía")
	_teardown()


func test_autosave_on_big_chests_and_the_antechamber() -> void:
	await _setup()
	await saves.load_scenario("pre_boss")
	assert_eq(saves.current_slot, saves.SCENARIO_SLOT, "un escenario no guarda en las ranuras del jugador")
	await tree.create_timer(0.5).timeout
	saves.current_slot = 2
	var count := [0]
	saves.saved.connect(func(_slot: int) -> void: count[0] += 1)
	var level := tree.current_scene
	(level.get_node(^"Antesala") as Room).mark_entered()
	await tree.process_frame
	assert_eq(count[0], 1, "entrar a la antesala guarda")
	var chest: Chest = load("res://src/world/chest.tscn").instantiate()
	chest.item = Items.get_item(&"compass")
	chest.big = true
	level.add_child(chest)
	chest.global_position = Vector3(20, 0, 30)
	chest.interactable.interact(tree.get_first_node_in_group(&"player"))
	await tree.process_frame
	assert_eq(count[0], 2, "abrir un cofre grande guarda")
	assert_eq(saves.has_save(saves.AUTO_SLOT), true, "en la ranura Auto")
	assert_eq(saves.has_save(2), false, "no en la del jugador")
	var stack: Node = tree.root.get_node(^"MenuStack")
	await tree.create_timer(1.0).timeout
	while stack.is_open():
		stack.pop()
	_teardown()


func test_play_time_counts_while_playing() -> void:
	await _setup()
	await tree.root.get_node(^"SceneFlow").new_game(1)
	var before: float = state.play_time
	await tree.create_timer(0.5).timeout
	assert_true(state.play_time - before > 0.3, "el tiempo jugado avanza")
	tree.paused = true
	var paused_at: float = state.play_time
	await tree.create_timer(0.3, true).timeout
	assert_eq(state.play_time, paused_at, "en pausa no cuenta")
	tree.paused = false
	saves.autosave()
	assert_true(saves.slot_summary(saves.AUTO_SLOT).play_time > 0.3, "y se guarda")
	_teardown()


func _title() -> void:
	tree.change_scene_to_file("res://src/ui/title/title_screen.tscn")
	await tree.scene_changed
	await tree.process_frame


func test_file_select_screen() -> void:
	await _setup()
	await tree.root.get_node(^"SceneFlow").new_game(1)
	await _title()
	var screen: FileSelect = tree.current_scene.open_file_select(FileSelect.Mode.PLAY)
	await tree.process_frame
	await tree.process_frame
	var cards := screen.find_children("*", "SlotCard", true, false)
	assert_eq(cards.size(), 4, "la Auto y tres ranuras")
	var auto := cards[0] as SlotCard
	assert_eq(auto.slot, saves.AUTO_SLOT, "la Auto arriba")
	assert_true(auto.visible and not auto.summary.is_empty())
	assert_eq((auto.find_child("Number", true, false) as Label).text, "AUTO")
	assert_eq((cards[1] as SlotCard).summary.is_empty(), false)
	assert_eq((cards[3] as SlotCard).summary.is_empty(), true, "las vacías ofrecen nueva partida")
	assert_true(tree.root.gui_get_focus_owner() == auto, "la más reciente tiene el foco")
	screen._set_mode(FileSelect.Mode.DELETE)
	(cards[1] as SlotCard).pressed.emit()
	await tree.process_frame
	var stack: Node = tree.root.get_node(^"MenuStack")
	var confirm := stack.top() as ConfirmDialog
	assert_true(confirm != null, "borrar pide confirmación")
	assert_eq(screen.can_process(), false, "la selección de abajo no recibe input")
	assert_eq(saves.has_save(1), true, "todavía no borró")
	assert_true(tree.root.gui_get_focus_owner().name == &"No", "con el foco en Cancelar")
	(confirm.find_child("Yes", true, false) as Button).pressed.emit()
	await tree.process_frame
	assert_eq(saves.has_save(1), false, "confirmado, borra")
	assert_true(stack.top() == screen and screen.can_process(), "vuelve a la selección")
	stack.clear()
	_teardown()


func test_new_game_picks_where_and_confirms_overwriting() -> void:
	await _setup()
	await tree.root.get_node(^"SceneFlow").new_game(1)
	await _title()
	var title := tree.current_scene
	(title.get_node(^"%NewGame") as Button).pressed.emit()
	await tree.process_frame
	await tree.process_frame
	var stack: Node = tree.root.get_node(^"MenuStack")
	var screen := stack.top() as FileSelect
	assert_true(screen != null and screen.mode == FileSelect.Mode.NEW, "con partidas, Nueva partida pregunta dónde")
	var cards := screen.find_children("*", "SlotCard", true, false)
	assert_eq((cards[0] as SlotCard).visible, false, "la Auto no se elige para empezar")
	assert_true(tree.root.gui_get_focus_owner() == cards[2], "el foco en la primera libre")
	var picked := [-1]
	screen.chosen.connect(func(slot: int, fresh: bool) -> void: picked[0] = slot if fresh else -2)
	(cards[1] as SlotCard).pressed.emit()
	await tree.process_frame
	var confirm := stack.top() as ConfirmDialog
	assert_true(confirm != null, "una ocupada pide confirmar")
	(confirm.find_child("No", true, false) as Button).pressed.emit()
	await tree.process_frame
	assert_eq(picked[0], -1, "cancelar no toca la partida")
	assert_true(saves.has_save(1))
	(cards[1] as SlotCard).pressed.emit()
	await tree.process_frame
	((stack.top() as ConfirmDialog).find_child("Yes", true, false) as Button).pressed.emit()
	await tree.process_frame
	assert_eq(picked[0], 1, "confirmado, empieza de cero ahí")
	await tree.scene_changed
	await tree.create_timer(0.8).timeout
	assert_eq(state.inventory.has(&"bomb_bag"), false)
	_teardown()


func test_title_continues_straight_into_the_latest_game() -> void:
	await _setup()
	await _title()
	var title := tree.current_scene
	assert_eq((title.get_node(^"%Continue") as Button).disabled, true, "sin partidas no hay Continuar")
	assert_eq((title.get_node(^"%Load") as Button).disabled, true, "ni Cargar")
	await tree.root.get_node(^"SceneFlow").new_game(2)
	state.give(Items.get_item(&"bomb_bag"))
	saves.autosave()
	state.reset()
	await _title()
	title = tree.current_scene
	(title.get_node(^"%Continue") as Button).pressed.emit()
	await tree.scene_changed
	await tree.create_timer(0.8).timeout
	var stack: Node = tree.root.get_node(^"MenuStack")
	assert_eq(stack.is_open(), false, "sin pasar por la selección")
	assert_eq(tree.current_scene.scene_file_path, "res://levels/overworld.tscn", "entra a la partida")
	assert_eq(state.inventory.has(&"bomb_bag"), true, "la del autosave")
	assert_eq(saves.current_slot, 2)
	_teardown()


func test_new_game_without_saves_goes_to_the_first_slot() -> void:
	await _setup()
	await _title()
	(tree.current_scene.get_node(^"%NewGame") as Button).pressed.emit()
	await tree.scene_changed
	await tree.create_timer(0.8).timeout
	assert_eq(tree.current_scene.scene_file_path, "res://levels/overworld.tscn", "directo a jugar")
	assert_eq(saves.current_slot, 1)
	assert_eq(saves.has_save(1), true)
	_teardown()
