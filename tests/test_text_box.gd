extends "res://tests/test_case.gd"

const TEXT := "~ start\nPrimera página de la tablilla.\nSegunda página, un poco más larga que la primera.\nTercera y última.\n=> END"


func _key(tree: SceneTree) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = true
	tree.root.push_input(event)


func _pad(tree: SceneTree) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_A
	event.pressed = true
	tree.root.push_input(event)


func _read_all(tree: SceneTree, press: Callable) -> void:
	var stack: Node = tree.root.get_node(^"MenuStack")
	var box := TextBox.open(DialogueManager.create_resource_from_text(TEXT), "start")
	assert_true(tree.paused, "pausa mientras está abierta")
	press.call(tree)
	assert_eq(box.page, 0, "el primer toque, muy pronto, no hace nada")
	await tree.create_timer(0.3).timeout
	press.call(tree)
	assert_true(box.is_page_done(), "apretar mientras escribe completa la página")
	press.call(tree)
	assert_eq(box.page, 0, "apretar rápido de nuevo no pasa de página")
	await tree.create_timer(0.3).timeout
	press.call(tree)
	assert_eq(box.page, 1, "segunda página")
	await tree.create_timer(2.0).timeout
	assert_true(box.is_page_done(), "la página se escribe sola")
	press.call(tree)
	assert_eq(box.page, 2, "tercera página")
	await tree.create_timer(0.3).timeout
	press.call(tree)
	await tree.create_timer(0.3).timeout
	press.call(tree)
	await tree.process_frame
	assert_eq(stack.is_open(), false, "termina y cierra")
	assert_eq(tree.paused, false)


func test_three_pages_with_keyboard() -> void:
	await _read_all(Engine.get_main_loop() as SceneTree, _key)


func test_three_pages_with_gamepad() -> void:
	await _read_all(Engine.get_main_loop() as SceneTree, _pad)


func test_dialogue_reads_and_sets_flags() -> void:
	var state: Node = (Engine.get_main_loop() as SceneTree).root.get_node(^"GameState")
	state.reset()
	var text := "~ start\nif not GameState.get_flag(\"ow_test_chest\")\n\tdo GameState.set_flag(\"ow_test_chest\", true)\n\tPrimera vez.\nelse\n\tYa lo sabías.\n=> END"
	var resource := DialogueManager.create_resource_from_text(text)
	var line: DialogueLine = await DialogueManager.get_next_dialogue_line(resource, "start")
	assert_eq(line.text, "Primera vez.")
	assert_eq(state.get_flag(&"ow_test_chest"), true, "el diálogo pone el flag")
	line = await DialogueManager.get_next_dialogue_line(resource, "start")
	assert_eq(line.text, "Ya lo sabías.", "y lo lee la próxima vez")
	state.reset()
