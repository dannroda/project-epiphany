extends "res://tests/test_case.gd"
## Co-op (13.1): un segundo player en la escena no rompe nada y la IA elige al más cercano.

const PLAYER := preload("res://player/player.tscn")


func _load(level: String) -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.get_node(^"GameState").reset()
	tree.change_scene_to_file(level)
	await tree.scene_changed
	for i in 5:
		await tree.physics_frame
	var players: Node = tree.root.get_node(^"Players")
	var first: PlayerCharacter = players.lead()
	var second := PLAYER.instantiate() as PlayerCharacter
	tree.current_scene.add_child(second)
	second.global_position = first.global_position + Vector3(3, 0, 0)
	for i in 10:
		await tree.physics_frame
	return [tree, players, first, second]


func test_registry_tracks_who_joins_and_leaves() -> void:
	var setup: Array = await _load("res://levels/test.tscn")
	var players: Node = setup[1]
	var first: PlayerCharacter = setup[2]
	var second: PlayerCharacter = setup[3]
	assert_eq(players.all.size(), 2, "dos players")
	assert_true(players.lead() == first, "el de la escena es el primero")
	assert_true(players.nearest(second.global_position + Vector3(0.5, 0, 0)) == second, "el más cercano")
	var gone: Array = []
	players.left.connect(func(player: PlayerCharacter) -> void: gone.append(player), CONNECT_ONE_SHOT)
	second.free()
	assert_true(gone.size() == 1 and gone[0] == second, "avisa cuando se va")
	assert_true(players.all.size() == 1 and players.all[0] == first)


func test_enemies_chase_the_nearest_player() -> void:
	var setup: Array = await _load("res://levels/test.tscn")
	var tree: SceneTree = setup[0]
	var first: PlayerCharacter = setup[2]
	var second: PlayerCharacter = setup[3]
	var enemy := tree.get_first_node_in_group(&"enemies") as Enemy
	first.global_position = enemy.global_position + Vector3(0, 0, 9)
	second.global_position = enemy.global_position + Vector3(0, 0, -3)
	enemy.bt_player.blackboard.set_var(&"target", null)
	var target: Variant = null
	for i in 60:
		await tree.physics_frame
		target = enemy.bt_player.blackboard.get_var(&"target", null)
		if target != null:
			break
	assert_true(target == second, "va por el que tiene más cerca (%s)" % (target.name if target else "nadie"))
	second.free()


func test_spawn_places_everyone_side_by_side() -> void:
	var setup: Array = await _load("res://levels/test.tscn")
	var first: PlayerCharacter = setup[2]
	var second: PlayerCharacter = setup[3]
	var save: Node = (Engine.get_main_loop() as SceneTree).root.get_node(^"SceneFlow")
	save.place_players(Vector3(2, 0, 2))
	assert_true(first.global_position.is_equal_approx(Vector3(2, 0, 2)), str(first.global_position))
	assert_true(second.global_position.distance_to(first.global_position) > 1.0, "el segundo al costado")
	second.free()


func test_two_players_in_the_overworld_and_the_temple() -> void:
	for level in ["res://levels/overworld.tscn", "res://levels/templo.tscn"]:
		var setup: Array = await _load(level)
		var tree: SceneTree = setup[0]
		var second: PlayerCharacter = setup[3]
		second.global_position += Vector3(0, 0, -2)
		for i in 30:
			await tree.physics_frame
		assert_eq(setup[1].all.size(), 2, "%s: los dos siguen" % level.get_file())
		assert_true(not second.is_dead and second.is_on_floor(), "%s: el segundo está parado en el piso" % level.get_file())
		second.free()
	(Engine.get_main_loop() as SceneTree).root.get_node(^"GameState").reset()
