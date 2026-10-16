extends "res://tests/test_case.gd"
## Pantalla de controles y pestaña Sistema de la pausa (10.29).

const SYSTEM_PAGE := 3


func _press(tree: SceneTree, action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	tree.root.push_input(event)
	await tree.process_frame


func _rows_have_icons(root: Node) -> void:
	for row: ControlRow in root.find_children("*", "ControlRow", true, false):
		var first := row.icons.get_child(0) as TextureRect
		assert_true(first.visible and first.texture != null, "%s tiene ícono" % row.get_path())


func test_controls_screen_from_options() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	OptionsScreen.open()
	await tree.process_frame
	(MenuStack.top().find_child("ShowControls", true, false) as Button).pressed.emit()
	await tree.process_frame
	var screen := MenuStack.top() as ControlsScreen
	assert_true(screen != null, "Ver controles abre la pantalla")
	var gamepad := InputDevice.current == InputDevice.Device.GAMEPAD
	assert_eq(screen.view.gamepad, gamepad, "arranca en el dispositivo en uso")
	await _press(tree, &"ui_tab_right")
	assert_eq(screen.view.gamepad, not gamepad, "LB/RB cambia de vista")
	assert_eq(screen.view.pad_diagram.visible, screen.view.gamepad)
	_rows_have_icons(screen.view)
	var move := screen.view.keyboard_diagram.find_child("Move", true, false).get_node(^"Rows/Row0") as ControlRow
	assert_eq(move.icons.get_children().filter(func(icon: Control) -> bool: return icon.visible).size(), 4, "WASD")
	await _press(tree, &"ui_cancel")
	assert_true(MenuStack.top() is OptionsScreen, "atrás vuelve a opciones")
	MenuStack.clear()


func test_system_tab_saves_over_the_loaded_game_and_loads() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	GameState.reset()
	tree.change_scene_to_file("res://levels/test.tscn")
	await tree.scene_changed
	await tree.process_frame
	SaveManager.current_slot = 2
	SaveManager.save_game()
	SaveManager.save_game(SaveManager.AUTO_SLOT)
	var before: float = SaveManager.slot_summary(2).timestamp
	var menu: Control = load("res://src/ui/menus/pause_menu.tscn").instantiate()
	MenuStack.push(menu)
	await tree.process_frame
	menu.show_page(SYSTEM_PAGE)
	await tree.process_frame
	var page: Control = menu.pages.get_node(^"Sistema")
	assert_true(page.get_node(^"%ControlsPanel").visible, "a la derecha, los controles")
	var gamepad: bool = page.view.gamepad
	await _press(tree, &"ui_toggle_view")
	assert_eq(page.view.gamepad, not gamepad, "Y/T cambia de vista")

	page.get_node(^"%Save").pressed.emit()
	await tree.process_frame
	assert_true(page.get_node(^"%SavePanel").visible, "Guardar muestra la partida cargada")
	assert_eq(page.save_card.number.text, "2")
	assert_true(not page.save_card.summary.is_empty())
	page.get_node(^"%SaveConfirm").pressed.emit()
	await tree.process_frame
	assert_true(SaveManager.slot_summary(2).timestamp > before, "y guarda sobre ella")
	assert_true(page.get_node(^"%ControlsPanel").visible, "vuelve a los controles")

	page.get_node(^"%Load").pressed.emit()
	await tree.process_frame
	assert_true(page.get_node(^"%LoadPanel").visible, "Cargar muestra checkpoint y guardado")
	assert_true(page.load_auto.visible and page.load_auto.has_focus(), "el checkpoint primero")
	page.load_slot.grab_focus()
	assert_eq(page._load_slot, 2, "elegir lo guardado")
	await _press(tree, &"ui_cancel")
	assert_true(MenuStack.top() == menu, "atrás no cierra la pausa")
	assert_true(page.get_node(^"%ControlsPanel").visible, "vuelve a los controles")

	page.get_node(^"%ToTitle").pressed.emit()
	await tree.process_frame
	assert_true(MenuStack.top() is ConfirmDialog, "volver al título pregunta")
	MenuStack.clear()
	SaveManager.current_slot = 1
	GameState.reset()
