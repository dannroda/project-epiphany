extends "res://tests/test_case.gd"

const LEVEL := "res://levels/overworld.tscn"
const ARROW := preload("res://src/items/arrow/arrow.tscn")


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


func _load(tree: SceneTree, items: Array) -> Array:
	var state: Node = tree.root.get_node(^"GameState")
	state.reset()
	for entry in items:
		state.give(Items.get_item(entry[0]), entry[1])
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	for enemy in tree.get_nodes_in_group(&"enemies"):
		enemy.free()
	await tree.physics_frame
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	player.health.invulnerability_time = 0.0
	return [state, tree.current_scene, player]


func _open_chest(tree: SceneTree, chest: Chest, player: PlayerCharacter) -> void:
	var stack: Node = tree.root.get_node(^"MenuStack")
	chest.interactable.interact(player)
	await tree.create_timer(1.0).timeout
	while stack.is_open():
		stack.pop()
	await tree.create_timer(1.2).timeout


func test_find_the_three_secrets_with_everything() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var setup: Array = await _load(tree, [[&"bomb_bag", 1], [&"bow", 1], [&"arrow", 30]])
	var state: Node = setup[0]
	var level: Node = setup[1]
	var player: PlayerCharacter = setup[2]

	var wall := level.get_node(^"GrottoCrackedWall") as CrackedWall
	state.item_buttons[0] = &"bomb_bag"
	player.global_position = wall.global_position + Vector3(2.1, 0, 0)
	_face(player, Vector3.LEFT)
	await tree.physics_frame
	await _press(tree, &"item_1")
	await tree.create_timer(1.0).timeout
	player.global_position = Vector3(-4, 0, 16)
	await tree.create_timer(2.6).timeout
	assert_eq(wall.is_broken, true, "una bomba abre la gruta")
	await _open_chest(tree, level.get_node(^"GrottoChest"), player)
	assert_eq(state.inventory.has(&"potion"), true, "la gruta guarda la poción")

	var grove_gate := level.get_node(^"GroveGate") as Gate
	player.global_position = Vector3(22, 0, 0)
	await tree.physics_frame
	var block_a := level.get_node(^"GroveBlockA") as PushBlock
	var block_b := level.get_node(^"GroveBlockB") as PushBlock
	for push in [[block_a, Vector3.BACK], [block_a, Vector3.BACK], [block_b, Vector3.RIGHT], [block_b, Vector3.BACK]]:
		assert_true(push[0].try_push(push[1]), "%s avanza hacia %s" % [push[0].name, push[1]])
		await tree.create_timer(0.6).timeout
	await tree.create_timer(0.6).timeout
	assert_eq(grove_gate.is_open, true, "los dos bloques en sus interruptores abren la reja")
	await _open_chest(tree, level.get_node(^"GroveChest"), player)
	assert_eq(state.inventory.has(&"armor_chainmail"), true, "la arboleda guarda la cota")
	assert_eq(state.equipment[ItemData.Category.ARMOR], &"tunic", "la cota no se equipa sola: hay que ir a Equipo")

	var eye := level.get_node(^"CliffEye") as EyeSwitch
	var cliff_gate := level.get_node(^"CliffGate") as Gate
	player.global_position = Vector3(26, 0, -15)
	await tree.physics_frame
	var arrow: Projectile = ARROW.instantiate()
	level.add_child(arrow)
	var from := Vector3(26, 1.2, -16)
	var target := eye.eye.global_position
	var info := Items.get_item(&"bow").make_damage(player)
	info.team = EntityConfig.Team.PLAYER
	arrow.launch(from, (target - from).normalized() * 20.0, info)
	await tree.create_timer(0.8).timeout
	assert_eq(eye.active, true, "una flecha por encima del abismo despierta el ojo")
	await tree.create_timer(0.8).timeout
	assert_eq(cliff_gate.is_open, true, "el ojo abre el nicho")
	var arrows_capacity: int = state.inventory.capacity(&"arrow")
	await _open_chest(tree, level.get_node(^"QuiverChest"), player)
	assert_eq(state.inventory.capacity(&"arrow"), arrows_capacity + 20, "el carcaj grande suma flechas")
	state.reset()


func test_without_the_bow_the_eye_stays_shut() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var setup: Array = await _load(tree, [])
	var level: Node = setup[1]
	var player: PlayerCharacter = setup[2]
	var eye := level.get_node(^"CliffEye") as EyeSwitch
	var slash := Items.get_item(&"sword_basic").make_damage(player)
	slash.team = EntityConfig.Team.PLAYER
	eye.hurtbox.receive(slash)
	await tree.physics_frame
	assert_eq(eye.active, false, "la espada no despierta el ojo")
	assert_eq((level.get_node(^"CliffGate") as Gate).is_open, false, "el carcaj sigue encerrado")
	setup[0].reset()
