extends "res://tests/test_case.gd"
## 11.34 paso 5: rayo de espada. Con la vida llena y la técnica de la Cumbre, cada golpe tira un rayo de 6 m que hace 1
## de daño y solo le pega a enemigos: no prende ojos ni interruptores, ni rompe nada, y se deshace contra una pared.

const LEVEL := "res://levels/test/test.tscn"
const BEAM := preload("res://src/combat/sword_beam.tscn")
const EYE := preload("res://src/world/puzzles/eye_switch.tscn")
const HIT_SWITCH := preload("res://src/world/puzzles/hit_switch.tscn")
const AWAY := Vector3(1, 0, 0)


func _level(learned := true) -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	var state := tree.root.get_node(^"GameState")
	state.reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	var enemy := tree.current_scene.get_node(^"Enemy") as Enemy
	for other in tree.get_nodes_in_group(&"enemies"):
		if other != enemy:
			other.free()
	if learned:
		state.set_flag(&"ow_tech_beam", true)
	for i in 300:
		if player.movement_state.get_active_state().name == &"Idle":
			break
		await tree.physics_frame
	enemy.bt_player.active = false
	enemy.global_position = player.global_position + AWAY * 4.0
	return [tree, player, enemy]


func _swing(tree: SceneTree, player: PlayerCharacter) -> void:
	player.model.look_at(player.model.global_position - AWAY, Vector3.UP)
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = &"attack"
		event.pressed = pressed
		Input.parse_input_event(event)
	for i in 50:
		await tree.physics_frame


func _done(tree: SceneTree) -> void:
	await tree.physics_frame
	tree.root.get_node(^"GameState").reset()


func test_at_full_health_a_swing_throws_a_beam() -> void:
	var setup: Array = await _level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var enemy: Enemy = setup[2]
	var before := enemy.health.current
	await _swing(tree, player)
	assert_eq(before - enemy.health.current, 1, "el rayo le pega a 4 m y hace 1")
	await _done(tree)


func test_without_full_health_there_is_no_beam() -> void:
	var setup: Array = await _level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var enemy: Enemy = setup[2]
	player.health.current = player.health.max_health - 1
	var before := enemy.health.current
	await _swing(tree, player)
	assert_eq(enemy.health.current, before, "sin la vida llena, solo la espada")
	await _done(tree)


func test_without_the_technique_there_is_no_beam() -> void:
	var setup: Array = await _level(false)
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var enemy: Enemy = setup[2]
	var before := enemy.health.current
	await _swing(tree, player)
	assert_eq(enemy.health.current, before, "sin la piedra de la Cumbre no hay rayo")
	await _done(tree)


func test_it_reaches_six_meters() -> void:
	var setup: Array = await _level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var enemy: Enemy = setup[2]
	enemy.global_position = player.global_position + AWAY * 7.5
	var before := enemy.health.current
	await _swing(tree, player)
	assert_eq(enemy.health.current, before, "a 7,5 m no llega")
	await _done(tree)


func test_a_wall_stops_it() -> void:
	var setup: Array = await _level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var enemy: Enemy = setup[2]
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.3, 3, 3)
	shape.shape = box
	wall.add_child(shape)
	tree.current_scene.add_child(wall)
	wall.global_position = player.global_position + AWAY * 2.2 + Vector3.UP * 1.5
	var before := enemy.health.current
	await _swing(tree, player)
	assert_eq(enemy.health.current, before, "la pared lo frena")
	await _done(tree)


func test_it_never_triggers_a_puzzle() -> void:
	var setup: Array = await _level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var enemy: Enemy = setup[2]
	enemy.free()
	var eye := EYE.instantiate()
	tree.current_scene.add_child(eye)
	eye.global_position = player.global_position + AWAY * 3.0
	eye.rotation.y = -PI / 2
	var post := HIT_SWITCH.instantiate()
	tree.current_scene.add_child(post)
	post.global_position = player.global_position + AWAY * 5.0
	await _swing(tree, player)
	assert_true(not eye.active and not post.active, "ni el ojo de piedra ni el cristal del poste")
	var shot := BEAM.instantiate() as Hitbox
	shot.team = player.hurtbox.team
	shot.damage_factory = func() -> DamageInfo: return DamageInfo.make(1, 2.0, player)
	tree.current_scene.add_child(shot)
	shot.global_position = Vector3(300, 0, 0)
	for hurtbox: Hurtbox in [eye.get_node(^"Hurtbox"), post.get_node(^"Hurtbox")]:
		shot._on_area_entered(hurtbox)
	await tree.physics_frame
	assert_true(not eye.active and not post.active, "aunque los toque de lleno")
	await _done(tree)
