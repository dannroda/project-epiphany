extends "res://tests/test_case.gd"

const TEST_DIR := "user://test_saves/"

var tree: SceneTree
var saves: Node
var state: Node


func _setup() -> void:
	tree = Engine.get_main_loop() as SceneTree
	saves = tree.root.get_node(^"SaveManager")
	state = tree.root.get_node(^"GameState")
	saves.save_dir = TEST_DIR
	for slot in 3:
		saves.delete_slot(slot)
	state.reset()


func _teardown() -> void:
	for slot in 3:
		saves.delete_slot(slot)
	saves.save_dir = "user://saves/"
	saves.current_slot = 0
	state.reset()


func test_two_slots_do_not_overwrite_each_other() -> void:
	await _setup()
	assert_eq(await saves.new_game(0), OK)
	assert_eq(saves.has_save(0), true, "nueva partida guarda enseguida en su ranura")
	state.give(Items.get_item(&"bomb_bag"))
	saves.autosave()
	assert_eq(await saves.new_game(1), OK)
	assert_eq(state.inventory.has(&"bomb_bag"), false, "la ranura 2 arranca de cero")
	saves.autosave()
	assert_true(&"bomb_bag" in saves.slot_summary(0).items, "la ranura 1 conserva las bombas")
	assert_eq(&"bomb_bag" in saves.slot_summary(1).items, false, "y la 2 no las tiene")
	assert_eq(await saves.load_game(0), OK)
	assert_eq(saves.current_slot, 0, "cargar elige la ranura")
	assert_eq(state.inventory.has(&"bomb_bag"), true)
	assert_eq(saves.latest_slot(), 1, "la más reciente")
	assert_eq(saves.slot_summary(0).location, "Claro del inicio", "guarda la ubicación")
	_teardown()


func test_a_cut_save_falls_back_to_the_backup() -> void:
	await _setup()
	await saves.new_game(0)
	state.give(Items.get_item(&"bomb_bag"))
	saves.autosave()
	var file := FileAccess.open(saves.slot_path(0), FileAccess.WRITE)
	file.store_string("[player]\nmax_hea")
	file.close()
	state.reset()
	assert_eq(await saves.load_game(0), OK, "un guardado cortado no rompe la partida")
	assert_eq(state.max_health, 12, "se usó la copia de respaldo")
	_teardown()


func test_copy_and_delete() -> void:
	await _setup()
	await saves.new_game(0)
	assert_eq(saves.copy_slot(0, 2), OK)
	assert_eq(saves.slot_summary(2).location, saves.slot_summary(0).location, "copiar duplica la partida")
	saves.delete_slot(2)
	assert_eq(saves.has_save(2), false, "borrar la deja vacía")
	_teardown()


func test_autosave_on_big_chests_and_the_antechamber() -> void:
	await _setup()
	saves.current_slot = 2
	await saves.load_scenario("pre_boss")
	await tree.create_timer(0.5).timeout
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
	assert_eq(saves.has_save(2), true)
	var stack: Node = tree.root.get_node(^"MenuStack")
	await tree.create_timer(1.0).timeout
	while stack.is_open():
		stack.pop()
	_teardown()


func test_play_time_counts_while_playing() -> void:
	await _setup()
	await saves.new_game(0)
	var before: float = state.play_time
	await tree.create_timer(0.5).timeout
	assert_true(state.play_time - before > 0.3, "el tiempo jugado avanza")
	tree.paused = true
	var paused_at: float = state.play_time
	await tree.create_timer(0.3, true).timeout
	assert_eq(state.play_time, paused_at, "en pausa no cuenta")
	tree.paused = false
	saves.autosave()
	assert_true(saves.slot_summary(0).play_time > 0.3, "y se guarda")
	_teardown()


func test_file_select_screen() -> void:
	await _setup()
	await saves.new_game(0)
	tree.change_scene_to_file("res://src/ui/title/title_screen.tscn")
	await tree.scene_changed
	await tree.process_frame
	var screen: FileSelect = tree.current_scene.open_file_select(0)
	await tree.process_frame
	await tree.process_frame
	var cards := screen.find_children("*", "SlotCard", true, false)
	assert_eq(cards.size(), 3, "tres ranuras")
	assert_eq((cards[0] as SlotCard).summary.is_empty(), false)
	assert_eq((cards[2] as SlotCard).summary.is_empty(), true, "las vacías ofrecen nueva partida")
	assert_true(tree.root.gui_get_focus_owner() == cards[0], "la ranura pedida tiene el foco")
	screen._set_mode(FileSelect.Mode.DELETE)
	(screen.find_children("*", "SlotCard", true, false)[0] as SlotCard).pressed.emit()
	await tree.process_frame
	var confirm := screen.get_node_or_null(^"Confirm")
	assert_true(confirm != null, "borrar pide confirmación")
	assert_eq(saves.has_save(0), true, "todavía no borró")
	assert_true(tree.root.gui_get_focus_owner().name == &"No", "con el foco en Cancelar")
	(confirm.find_child("Yes", true, false) as MenuItem).pressed.emit()
	await tree.process_frame
	assert_eq(saves.has_save(0), false, "confirmado, borra")
	_teardown()
