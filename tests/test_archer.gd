extends "res://tests/test_case.gd"

const LEVEL := "res://levels/test.tscn"
const ARCHER := preload("res://src/entities/archer_skeleton.tscn")


func _setup(distance: float) -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	state.reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	for i in 3:
		await tree.physics_frame
	for enemy in tree.get_nodes_in_group(&"enemies"):
		enemy.free()
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	player.health.invulnerability_time = 0.0
	var archer: Enemy = ARCHER.instantiate()
	tree.current_scene.add_child(archer)
	archer.global_position = player.global_position + Vector3(distance, 0, 0)
	return [tree, state, player, archer]


func _block(pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = &"block"
	event.pressed = pressed
	Input.parse_input_event(event)


func test_draws_and_shoots_an_arrow() -> void:
	var setup: Array = await _setup(6.0)
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[2]
	var archer: Enemy = setup[3]
	var before := player.health.current
	await tree.create_timer(0.5).timeout
	assert_eq(archer.anim_player.current_animation, &"CombatRanged/Ranged_Bow_Draw", "tensa antes de tirar")
	assert_true(archer.find_child("Bow", true, false).draw > 0.2, "el arco se tensa")
	await tree.create_timer(1.2).timeout
	assert_true(player.health.current < before, "la flecha le pega (%d → %d)" % [before, player.health.current])
	setup[1].reset()


func test_shield_blocks_the_arrow() -> void:
	var setup: Array = await _setup(6.0)
	var tree: SceneTree = setup[0]
	var state: Node = setup[1]
	var player: PlayerCharacter = setup[2]
	state.give(Items.get_item(&"shield_wood"))
	state.equip(Items.get_item(&"shield_wood"))
	player.model.look_at(player.model.global_position + Vector3.LEFT, Vector3.UP)
	await tree.physics_frame
	_block(true)
	var before := player.health.current
	await tree.create_timer(1.8).timeout
	_block(false)
	assert_eq(player.health.current, before, "de frente, el escudo la frena")
	state.reset()


func test_backs_away_when_the_player_is_close() -> void:
	var setup: Array = await _setup(2.0)
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[2]
	var archer: Enemy = setup[3]
	await tree.create_timer(1.0).timeout
	assert_true(archer.global_position.distance_to(player.global_position) > 3.0, "retrocede (a %.1f m)" % archer.global_position.distance_to(player.global_position))
	setup[1].reset()


func test_a_close_player_does_not_cancel_the_shot() -> void:
	var setup: Array = await _setup(6.0)
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[2]
	var archer: Enemy = setup[3]
	var before := player.health.current
	await tree.create_timer(0.5).timeout
	player.global_position = archer.global_position + Vector3(-2.0, 0, 0)
	await tree.create_timer(0.3).timeout
	assert_eq(archer.anim_player.current_animation, &"CombatRanged/Ranged_Bow_Draw", "sigue tensando con el player encima")
	await tree.create_timer(0.6).timeout
	assert_true(player.health.current < before, "y dispara (%d → %d)" % [before, player.health.current])
	await tree.create_timer(1.2).timeout
	assert_true(archer.global_position.distance_to(player.global_position) > 3.0, "después se reacomoda (a %.1f m)" % archer.global_position.distance_to(player.global_position))
	setup[1].reset()
