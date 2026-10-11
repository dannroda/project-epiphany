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


func test_responses_show_inside_the_box_and_follow_the_choice() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var text := "~ start\nGuardián: ¿Qué hacés?\n- Pelear\n\tGuardián: Que así sea.\n- Huir [if false /]\n\tGuardián: No.\n- Charlar\n\tGuardián: Sentate.\n=> END"
	var box := TextBox.open(DialogueManager.create_resource_from_text(text), "start", TextBox.Style.ITEM)
	assert_true(not box.responses.visible, "mientras escribe, sin respuestas")
	await tree.create_timer(1.2).timeout
	assert_true(box.responses.visible, "al terminar la línea aparecen")
	assert_eq(box.responses.get_child_count(), 2, "las que no cumplen su condición no se muestran")
	var first := box.responses.get_child(0) as Button
	assert_true(first.has_focus(), "foco en la primera")
	assert_true(not box._next.visible, "sin la flecha de seguir")
	var down := InputEventAction.new()
	down.action = &"ui_down"
	down.pressed = true
	tree.root.push_input(down)
	await tree.process_frame
	assert_true((box.responses.get_child(1) as Button).has_focus(), "se baja con el stick o las flechas")
	_key(tree)
	await tree.create_timer(0.1).timeout
	assert_true(not box.responses.visible, "elegir las saca")
	assert_eq(box.body.text, "Sentate.", "y sigue por la respuesta elegida")
	MenuStack.clear()
	tree.paused = false
