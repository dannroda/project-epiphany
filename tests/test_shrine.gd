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


func test_bombs_open_the_shrine_and_the_mirror_from_d4_lights_its_chest() -> void:
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
	var spawn := level.get_node(^"Spawn_cueva") as Node3D
	assert_true(player.global_position.distance_to(spawn.global_position) < 0.5, "bombs_only arranca a la salida de la cueva")

	var wall := level.get_node(^"ShrineCrackedWall") as CrackedWall
	player.global_position = wall.global_position + Vector3(0, 0, 2.1)
	_face(player, Vector3.FORWARD)
	await _frames(tree, 2)
	await _press(tree, &"item_1")
	await tree.create_timer(1.0).timeout
	player.global_position = wall.global_position + Vector3(0, 0, 6.0)
	await tree.create_timer(2.6).timeout
	assert_eq(wall.is_broken, true, "la bomba abre el paso al santuario")

	tree.change_scene_to_file("res://levels/shrine_cave.tscn")
	await tree.scene_changed
	level = tree.current_scene
	player = tree.get_first_node_in_group(&"player") as PlayerCharacter
	var chest_gate := level.get_node(^"ChestGate") as Gate
	var shortcut := level.get_node(^"ShortcutGate") as Gate
	await _frames(tree, 2)
	assert_eq(chest_gate.is_open, false, "el cofre está detrás de una reja")
	assert_eq(shortcut.is_open, false, "y el atajo, cerrado")
	var block := level.get_node(^"ShrineBlock") as PushBlock
	for i in 2:
		assert_true(block.try_push(Vector3.FORWARD), "el bloque avanza")
		await tree.create_timer(0.6).timeout
	await tree.create_timer(0.8).timeout
	assert_eq(shortcut.is_open, true, "el bloque en el interruptor abre el atajo a la entrada del templo")
	assert_eq(chest_gate.is_open, false, "pero no el cofre")

	var crystal := level.get_node(^"ShrineCrystal") as LightReceiver
	player.global_position = Vector3(8, 0, 2)
	_face(player, Vector3(-1, 0, -1))
	hold_block(player, true)
	use_gamepad()
	await _frames(tree, 8)
	assert_eq(crystal.lit, false, "el escudo de madera no devuelve la luz")
	hold_block(player, false)
	state.give(Items.get_item(&"shield_mirror"))
	state.equip(Items.get_item(&"shield_mirror"))
	await _frames(tree, 2)
	_face(player, Vector3(-1, 0, -1))
	hold_block(player, true)
	await _frames(tree, 8)
	assert_eq(crystal.lit, true, "con el escudo espejo de D4 el haz llega al cristal")
	hold_block(player, false)
	await tree.create_timer(0.8).timeout
	assert_eq(chest_gate.is_open, true, "el cristal abre la reja del cofre")

	var hearts_before: int = state.max_health
	var chest := level.get_node(^"ShrineChest") as Chest
	player.global_position = chest.global_position + Vector3(0, 0, 1.4)
	_face(player, Vector3.FORWARD)
	await _frames(tree, 2)
	chest.interactable.interact(player)
	await tree.create_timer(1.0).timeout
	assert_true(stack.is_open() and stack.top().text_box.title_label.text == tr("ITEM_HEART_CONTAINER_GOT"), "item get del contenedor de corazón")
	while stack.is_open():
		stack.pop()
	await tree.create_timer(1.2).timeout
	assert_true(state.max_health > hearts_before, "suma un corazón")

	assert_eq(saves.save_game(SLOT), OK)
	state.reset()
	tree.change_scene_to_file("res://levels/test.tscn")
	await tree.scene_changed
	assert_eq(await saves.load_game(SLOT), OK)
	await _frames(tree, 2)
	tree.change_scene_to_file("res://levels/shrine_cave.tscn")
	await tree.scene_changed
	await _frames(tree, 2)
	level = tree.current_scene
	assert_eq((level.get_node(^"ChestGate") as Gate).is_open, true, "la reja del cofre sigue abierta al cargar")
	assert_eq((level.get_node(^"ShortcutGate") as Gate).is_open, true, "el atajo sigue abierto al cargar")
	assert_eq((level.get_node(^"ShrineCrystal") as LightReceiver).lit, true, "el cristal sigue encendido")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saves.slot_path(SLOT)))
	state.reset()


func _hold(tree: SceneTree, action: StringName, seconds: float) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	event.strength = 1.0
	Input.parse_input_event(event)
	await tree.create_timer(seconds).timeout
	var release := InputEventAction.new()
	release.action = action
	Input.parse_input_event(release)
	await _frames(tree, 2)


func test_the_back_door_skips_neither_the_shortcut_nor_the_cracked_wall() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	var flow: Node = tree.root.get_node(^"SceneFlow")
	state.reset()
	await flow.travel_to("res://levels/shrine_cave.tscn", &"atajo")
	await _frames(tree, 4)
	var level := tree.current_scene
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	assert_eq((level.get_node(^"ShortcutGate") as Gate).is_open, false, "el atajo arranca cerrado")
	assert_true(player.global_position.x > 13.0, "por atrás se entra del lado de afuera de la reja (%s)" % player.global_position)
	await _hold(tree, &"move_left", 1.2)
	assert_true(player.global_position.x > 12.5, "la reja cerrada no deja pasar al santuario (%s)" % player.global_position)

	var wall := level.get_node(^"EntranceCrackedWall") as CrackedWall
	assert_eq(wall.is_broken, false, "adentro, la salida a la explanada está tapada por el mismo muro agrietado")
	player.global_position = (level.get_node(^"Spawn_entrada") as Node3D).global_position
	await _hold(tree, &"move_backward", 1.2)
	assert_eq(flow.traveling, false, "sin romperlo no se sale por ahí")
	assert_eq(tree.current_scene, level, "y sigue en el santuario")

	state.set_flag(wall.flag, true)
	await _frames(tree, 2)
	assert_eq(wall.is_broken, true, "roto afuera (el mismo flag), queda roto adentro")
	state.reset()
