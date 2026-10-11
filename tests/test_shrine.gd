extends "res://tests/test_case.gd"

const LEVEL := "res://levels/overworld.tscn"
const SLOT := 9


func _press(tree: SceneTree, action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	var release := InputEventAction.new()
	release.action = action
	Input.parse_input_event(release)
	for i in 3:
		await tree.physics_frame


func _face(player: PlayerCharacter, direction: Vector3) -> void:
	player.model.look_at(player.model.global_position - direction.normalized(), Vector3.UP)


func _frames(tree: SceneTree, count: int) -> void:
	for i in count:
		await tree.physics_frame


func test_reach_the_shrine_get_the_mirror_and_light_the_crystal() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	var saves: Node = tree.root.get_node(^"SaveManager")
	var stack: Node = tree.root.get_node(^"MenuStack")
	state.reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	assert_eq(await saves.load_scenario("bombs_only"), OK)
	for enemy in tree.get_nodes_in_group(&"enemies"):
		enemy.free()
	var level := tree.current_scene
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	player.health.invulnerability_time = 0.0
	assert_true(player.global_position.distance_to(Vector3(-72, 0, -16)) < 0.5, "bombs_only arranca en la cueva")

	var wall := level.get_node(^"ShrineCrackedWall") as CrackedWall
	player.global_position = wall.global_position + Vector3(0, 0, 2.1)
	_face(player, Vector3.FORWARD)
	await _frames(tree, 2)
	await _press(tree, &"item_1")
	await tree.create_timer(1.0).timeout
	player.global_position = Vector3(-72, 0, -18)
	await tree.create_timer(2.6).timeout
	assert_eq(wall.is_broken, true, "la bomba abre el paso al santuario")

	var chest_gate := level.get_node(^"ChestGate") as Gate
	var shortcut := level.get_node(^"ShortcutGate") as Gate
	player.global_position = Vector3(-72, 0, -27)
	await _frames(tree, 2)
	assert_eq(chest_gate.is_open, false, "el cofre está detrás de una reja")
	assert_eq(shortcut.is_open, false, "y el atajo, cerrado")
	var block := level.get_node(^"ShrineBlock") as PushBlock
	for i in 2:
		assert_true(block.try_push(Vector3.FORWARD), "el bloque avanza")
		await tree.create_timer(0.6).timeout
	await tree.create_timer(0.8).timeout
	assert_eq(chest_gate.is_open, true, "el bloque en el interruptor abre la reja del cofre")

	var chest := level.get_node(^"MirrorChest") as Chest
	player.global_position = chest.global_position + Vector3(0, 0, 1.4)
	_face(player, Vector3.FORWARD)
	await _frames(tree, 2)
	chest.interactable.interact(player)
	await tree.create_timer(1.0).timeout
	assert_true(stack.is_open() and stack.top().text_box.title_label.text == tr("ITEM_SHIELD_MIRROR_GOT"), "item get del escudo espejo")
	while stack.is_open():
		stack.pop()
	await tree.create_timer(1.2).timeout
	assert_eq(state.equipment[ItemData.Category.SHIELD], &"shield_mirror", "se equipa solo")

	var crystal := level.get_node(^"ShrineCrystal") as LightReceiver
	player.global_position = Vector3(-64, 0, -30)
	_face(player, Vector3(-1, 0, -1))
	player.movement_state.blackboard.set_var("is_blocking", true)
	use_gamepad()
	player.set_guard(true)
	await _frames(tree, 8)
	assert_eq(crystal.lit, true, "el espejo manda el haz al cristal")
	player.set_guard(false)
	player.movement_state.blackboard.set_var("is_blocking", false)
	await tree.create_timer(0.8).timeout
	assert_eq(shortcut.is_open, true, "el cristal abre el atajo a la entrada del templo")
	assert_eq(state.get_flag(&"ow_shrine_shortcut"), true)

	assert_eq(saves.save_game(SLOT), OK)
	state.reset()
	tree.change_scene_to_file("res://levels/test.tscn")
	await tree.scene_changed
	assert_eq(await saves.load_game(SLOT), OK)
	await _frames(tree, 2)
	level = tree.current_scene
	assert_eq((level.get_node(^"ChestGate") as Gate).is_open, true, "la reja del cofre sigue abierta al cargar")
	assert_eq((level.get_node(^"ShortcutGate") as Gate).is_open, true, "el atajo sigue abierto al cargar")
	assert_eq((level.get_node(^"ShrineCrystal") as LightReceiver).lit, true, "el cristal sigue encendido")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saves.slot_path(SLOT)))
	state.reset()
