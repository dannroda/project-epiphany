extends "res://tests/test_case.gd"

const LEVEL := "res://levels/test.tscn"


func _setup() -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	state.reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	for i in 5:
		await tree.process_frame
	state.give(Items.get_item(&"potion"))
	state.assign_button(0, &"potion")
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	return [tree, state, player]


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


func test_potion_heals_and_leaves_the_bottle() -> void:
	var setup: Array = await _setup()
	var tree: SceneTree = setup[0]
	var state: Node = setup[1]
	var player: PlayerCharacter = setup[2]
	player.health.invulnerability_time = 0.0
	player.health.damage(6)
	await _press(tree, &"item_1")
	assert_eq(player.movement_state.get_active_state().name, &"UsingItem", "empieza a usar la poción")
	assert_eq(player.health.current, 6, "todavía no curó")
	await tree.create_timer(1.8).timeout
	assert_eq(player.health.current, player.health.max_health, "curó toda la vida")
	assert_eq(state.inventory.has(&"potion"), false)
	assert_eq(state.inventory.has(&"bottle_empty"), true, "deja la botella")
	assert_eq(state.item_buttons[0], &"bottle_empty", "la botella queda en X")
	assert_eq(player.movement_state.get_active_state().name, &"Idle")
	state.reset()


func test_full_health_denies_without_spending() -> void:
	var setup: Array = await _setup()
	var tree: SceneTree = setup[0]
	var state: Node = setup[1]
	var player: PlayerCharacter = setup[2]
	var denied: Array = []
	player.item_denied.connect(func(button: int) -> void: denied.append(button))
	await _press(tree, &"item_1")
	assert_eq(denied, [0], "avisa que no se puede")
	assert_true(player.movement_state.get_active_state().name != &"UsingItem", "no la toma")
	assert_eq(state.inventory.has(&"potion"), true, "no la gasta")
	await _press(tree, &"item_2")
	assert_eq(denied, [0, 1], "botón vacío también avisa")
	state.reset()


func test_potion_at_one_heart_leaves_empty_bottle() -> void:
	var setup: Array = await _setup()
	var tree: SceneTree = setup[0]
	var state: Node = setup[1]
	var player: PlayerCharacter = setup[2]
	player.health.invulnerability_time = 0.0
	player.health.damage(player.health.max_health - 4)
	assert_eq(player.health.current, 4, "un corazón")
	await _press(tree, &"item_1")
	await tree.create_timer(1.8).timeout
	assert_eq(player.health.current, player.health.max_health, "cura todo")
	assert_eq(state.inventory.has(&"bottle_empty"), true, "queda la botella vacía")
	assert_eq(state.inventory.has(&"potion"), false)
	state.reset()


func test_hit_while_drinking_wastes_the_moment_not_the_potion() -> void:
	var setup: Array = await _setup()
	var tree: SceneTree = setup[0]
	var state: Node = setup[1]
	var player: PlayerCharacter = setup[2]
	player.health.invulnerability_time = 0.0
	player.health.damage(6)
	await _press(tree, &"item_1")
	await tree.create_timer(0.3).timeout
	assert_eq(player.movement_state.get_active_state().name, &"UsingItem")
	var enemy := tree.get_first_node_in_group(&"enemies") as Enemy
	enemy.global_position = player.global_position + Vector3(0, 0, -1.5)
	player.hurtbox.receive(enemy.config.make_damage(enemy))
	await tree.physics_frame
	assert_eq(player.movement_state.get_active_state().name, &"Hurt", "un golpe corta el trago")
	await tree.create_timer(1.5).timeout
	assert_true(player.health.current < 6, "recibió el daño y no curó")
	assert_eq(state.inventory.has(&"potion"), true, "la poción no se gasta")
	state.reset()
