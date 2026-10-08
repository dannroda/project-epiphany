extends "res://tests/test_case.gd"

const LEVEL := "res://levels/test.tscn"


func _finish(tree: SceneTree, box: TextBox) -> void:
	while is_instance_valid(box) and not box.is_queued_for_deletion():
		await tree.create_timer(0.3).timeout
		if is_instance_valid(box):
			box.advance()
	await tree.process_frame


func test_read_tablets_and_keep_read_flag() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	var stack: Node = tree.root.get_node(^"MenuStack")
	state.reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	await tree.physics_frame
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	var lore: Tablet = tree.current_scene.get_node(^"TabletLore")
	var hint: Tablet = tree.current_scene.get_node(^"TabletHint")
	assert_eq(lore.interactable.prompt, "Leer")

	lore.interactable.interact(player)
	var box := stack.top() as TextBox
	assert_true(box != null, "abre la caja")
	assert_eq(box.data.style, TextData.Style.STONE)
	assert_eq(box.title_label.text, "Tablilla antigua")
	assert_eq(box.data.pages.size(), 2)
	await _finish(tree, box)
	assert_eq(stack.is_open(), false)
	assert_eq(lore.is_read(), false, "la de ambientación no tiene flag")

	assert_eq(hint.is_read(), false)
	hint.interactable.interact(player)
	await _finish(tree, stack.top())
	assert_eq(hint.is_read(), true, "la pista queda leída")

	var cfg := ConfigFile.new()
	state.write_to(cfg)
	state.reset()
	assert_eq(hint.is_read(), false)
	state.read_from(cfg)
	assert_eq(hint.is_read(), true, "guardar y cargar conserva las leídas")
	state.reset()
