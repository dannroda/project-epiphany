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
	await _frames(tree, 2)
	assert_eq(chest_gate.is_open, false, "el cofre está detrás de una reja")

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

	var chest := level.get_node(^"ShrineChest") as Chest
	player.global_position = chest.global_position + Vector3(0, 0, 1.4)
	_face(player, Vector3.FORWARD)
	await _frames(tree, 2)
	chest.interactable.interact(player)
	await tree.create_timer(1.0).timeout
	assert_true(stack.is_open() and stack.top().text_box.title_label.text == tr("ITEM_ARMOR_CHAINMAIL_GOT"), "item get de la cota reforzada")
	while stack.is_open():
		stack.pop()
	await tree.create_timer(1.2).timeout
	assert_true(state.inventory.has(&"armor_chainmail"), "el cofre guarda la cota")
	assert_eq(state.equipment[ItemData.Category.ARMOR], &"tunic", "la cota no se equipa sola: hay que ir a Equipo")

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
	assert_eq((level.get_node(^"ShrineCrystal") as LightReceiver).lit, true, "el cristal sigue encendido")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saves.slot_path(SLOT)))
	state.reset()


func test_the_only_way_in_is_the_cracked_wall() -> void:
	var level: Node = (load("res://levels/shrine_cave.tscn") as PackedScene).instantiate()
	var portals := level.find_children("*", "Area3D", true, false).filter(func(node: Node) -> bool: return node is Portal)
	assert_eq(portals.size(), 1, "una sola salida, la de la explanada")
	assert_eq(level.find_children("*", "Marker3D", true, false).filter(func(node: Node) -> bool: return node is SpawnPoint).size(), 1, "y una sola llegada")
	level.free()
