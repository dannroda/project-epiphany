extends "res://tests/test_case.gd"

const LEVEL := "res://levels/test.tscn"


## Lee hasta el final y devuelve cuántas líneas mostró.
func _finish(tree: SceneTree, box: TextBox) -> int:
	var shown := 0
	while is_instance_valid(box) and not box.is_queued_for_deletion():
		shown = box.page + 1
		await tree.create_timer(0.3).timeout
		if is_instance_valid(box):
			box.advance()
	await tree.process_frame
	return shown


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
	assert_eq(box.style, TextBox.Style.STONE)
	assert_eq(box.title_label.text, "Tablilla antigua", "el personaje del .dialogue es el rótulo")
	assert_eq(await _finish(tree, box), 2, "sin la pista leída: dos líneas")
	assert_eq(stack.is_open(), false)
	assert_eq(lore.is_read(), false, "la de ambientación no tiene flag")

	assert_eq(hint.is_read(), false)
	hint.interactable.interact(player)
	await _finish(tree, stack.top())
	assert_eq(hint.is_read(), true, "la pista queda leída")
	lore.interactable.interact(player)
	assert_eq(await _finish(tree, stack.top()), 3, "con la pista leída aparece una línea más")

	var cfg := ConfigFile.new()
	state.write_to(cfg)
	state.reset()
	assert_eq(hint.is_read(), false)
	state.read_from(cfg)
	assert_eq(hint.is_read(), true, "guardar y cargar conserva las leídas")
	state.reset()


func test_story_tablets_have_text_and_read_flag() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	var flags := {}
	var total := 0
	for path in ["res://levels/overworld.tscn", "res://levels/temple.tscn"]:
		state.reset()
		tree.change_scene_to_file(path)
		await tree.scene_changed
		for tablet: Tablet in tree.current_scene.find_children("*", "Tablet", false, false):
			total += 1
			assert_true(tablet.dialogue.cues.has(tablet.cue), "%s: el cue %s existe" % [tablet.name, tablet.cue])
			assert_true(state.FLAGS.has(tablet.flag), "%s tiene flag de leída registrado" % tablet.name)
			assert_true(not flags.has(tablet.flag), "%s no comparte flag" % tablet.name)
			flags[tablet.flag] = true
	assert_true(total >= 10, "tablillas entre overworld y templo: %d" % total)
	state.reset()
