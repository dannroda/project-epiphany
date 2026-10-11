extends "res://tests/test_case.gd"
## Co-op (13.4): inventario compartido con X/Y de cada uno, el caído queda como espíritu hasta que lo reviven,
## game over solo si caen los dos, y el corazón es del que lo toca.

const PICKUP := preload("res://src/world/pickup.tscn")
const PAD_1 := 0
const PAD_2 := 1


func _rooms() -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	var players: Node = tree.root.get_node(^"Players")
	tree.root.get_node(^"GameState").reset()
	tree.change_scene_to_file("res://levels/test_rooms.tscn")
	await tree.scene_changed
	for i in 4:
		await tree.physics_frame
	var level := tree.current_scene
	level.get_node(^"Skeleton").free()
	players.lead_pad = PAD_1
	var second: PlayerCharacter = players.join(PAD_2)
	for i in 3:
		await tree.physics_frame
	for player: PlayerCharacter in players.all:
		player.get_node(^"MovementState/Dead").delay = 0.1
	return [tree, level, players.lead(), second]


func _done() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var players: Node = tree.root.get_node(^"Players")
	for slot in players.guests.keys():
		players.leave(slot)
	players.lead_pad = -1
	MenuStack.clear()
	tree.paused = false
	await tree.process_frame
	tree.root.get_node(^"GameState").reset()


## Pasarlos a otra sala de golpe dispara el cruce, que junta al resto: se espera y se los vuelve a poner.
func _place(tree: SceneTree, spots: Dictionary) -> void:
	var camera := tree.get_first_node_in_group(&"room_camera") as TopDownCamera
	for attempt in 2:
		for player: PlayerCharacter in spots:
			player.global_position = spots[player]
		await _settle(tree, 0.05)
		if not camera.transitioning:
			return
		await _settle(tree, camera.transition_time + 0.2)


func _settle(tree: SceneTree, seconds: float) -> void:
	await tree.create_timer(seconds).timeout
	await tree.physics_frame


func test_each_player_assigns_their_own_buttons_from_the_shared_bag() -> void:
	var setup: Array = await _rooms()
	var first: PlayerCharacter = setup[2]
	var second: PlayerCharacter = setup[3]
	GameState.give(Items.get_item(&"bow"))
	GameState.give(Items.get_item(&"bomb_bag"))
	assert_eq(GameState.buttons_of(0), [&"bow", &"bomb_bag"] as Array[StringName], "lo nuevo va a los botones libres del P1")
	assert_eq(GameState.buttons_of(1), [&"", &""] as Array[StringName], "el P2 arranca con las manos vacías")

	assert_true(not GameState.assign_button(0, &"bomb_bag", 1), "un ítem lo lleva uno solo")
	assert_eq(GameState.owner_of(&"bomb_bag"), 0)
	GameState.assign_button(1, &"", 0)
	assert_true(GameState.assign_button(0, &"bomb_bag", 1), "suelto por el P1, lo toma el P2")
	assert_eq(second.usable_item(0).id, &"bomb_bag", "su X tira bombas")
	assert_eq(first.usable_item(0).id, &"bow", "la del P1 sigue con el arco")

	GameState.give(Items.get_item(&"potion"))
	assert_eq(GameState.buttons_of(0)[1], &"potion", "al primer botón libre")
	GameState.inventory.remove(&"potion")
	GameState.replace_on_buttons(&"potion", &"bottle_empty")
	assert_eq(GameState.buttons_of(0)[1], &"bottle_empty", "la poción tomada deja la botella")

	var players: Node = (Engine.get_main_loop() as SceneTree).root.get_node(^"Players")
	players.leave(1)
	assert_eq(GameState.owner_of(&"bomb_bag"), -1, "el que sale suelta lo suyo")
	await _done()


func test_the_fallen_floats_as_a_spirit_until_the_other_revives_them() -> void:
	var setup: Array = await _rooms()
	var tree: SceneTree = setup[0]
	var first: PlayerCharacter = setup[2]
	var second: PlayerCharacter = setup[3]
	await _place(tree, {first: Vector3(-2, 0, -20), second: Vector3(4, 0, -20)})
	first.health.damage(first.health.current)
	await _settle(tree, 0.3)
	assert_true(first.is_spirit(), "con el otro vivo, queda como espíritu")
	assert_true(not (MenuStack.top() is GameOver), "sin game over")
	assert_true(first.spirit.visible and not first.model.visible, "se ve el espíritu, no el cuerpo")
	await _settle(tree, 1.0)
	assert_true(first.global_position.distance_to(second.global_position) < 2.5, "sigue al vivo")
	assert_true(first.is_spirit(), "quedarse a distancia no lo revive")

	second.global_position = first.global_position + Vector3(0.5, 0, 0)
	await _settle(tree, 1.3)
	assert_true(not (first.is_dead), "tocarlo un momento lo revive")
	assert_eq(first.health.current, 4, "con un corazón")
	assert_true(first.model.visible and not first.spirit.visible, "vuelve el cuerpo")
	await _done()


func test_game_over_only_when_both_fall() -> void:
	var setup: Array = await _rooms()
	var tree: SceneTree = setup[0]
	var first: PlayerCharacter = setup[2]
	var second: PlayerCharacter = setup[3]
	second.health.damage(second.health.current)
	await _settle(tree, 0.3)
	assert_true(not (MenuStack.top() is GameOver), "cae uno: sigue")
	first.health.damage(first.health.current)
	await _settle(tree, 0.3)
	assert_true(MenuStack.top() is GameOver, "caen los dos: game over")
	await _done()


func test_crossing_into_another_room_revives_the_spirit() -> void:
	var setup: Array = await _rooms()
	var tree: SceneTree = setup[0]
	var level: Node = setup[1]
	var first: PlayerCharacter = setup[2]
	var second: PlayerCharacter = setup[3]
	var camera: TopDownCamera = level.get_node(^"TopDownCamera")
	first.global_position = Vector3(-1, 0, 2)
	second.global_position = Vector3(1, 0, 2)
	await _settle(tree, 0.2)
	second.health.damage(second.health.current)
	await _settle(tree, 0.3)
	assert_true(second.is_spirit())
	first.global_position = Vector3(0, 0, -5.4)
	await _settle(tree, camera.transition_time + 0.3)
	assert_eq(camera.room, level.get_node(^"RoomB"))
	assert_true(not (second.is_dead), "al pasar de sala revive")
	assert_eq(second.health.current, 4, "con un corazón")
	assert_true((level.get_node(^"RoomB") as Room).contains(second.global_position), "y entra con el otro")
	await _done()


func test_a_heart_heals_whoever_touches_it() -> void:
	var setup: Array = await _rooms()
	var tree: SceneTree = setup[0]
	var level: Node = setup[1]
	var first: PlayerCharacter = setup[2]
	var second: PlayerCharacter = setup[3]
	await _place(tree, {first: Vector3(-3, 0, -20), second: Vector3(3, 0, -20)})
	first.health.damage(4)
	second.health.damage(4)
	var first_hp := first.health.current
	var second_hp := second.health.current
	var heart: Pickup = PICKUP.instantiate()
	heart.heal = 4
	level.add_child(heart)
	heart.global_position = second.global_position
	await _settle(tree, 0.6)
	assert_true(not (is_instance_valid(heart)), "lo agarra")
	assert_eq(second.health.current, second_hp + 4, "cura al que lo tocó")
	assert_eq(first.health.current, first_hp, "al otro no")
	await _done()
