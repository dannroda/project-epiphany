extends "res://tests/test_case.gd"

const LEVEL := "res://levels/test/test.tscn"
const STONE := preload("res://src/world/stone.tscn")
const FLOOR_SWITCH := preload("res://src/world/floor_switch.tscn")


func _setup() -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	state.reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	for i in 3:
		await tree.physics_frame
	var skeleton: Enemy = null
	for enemy in tree.get_nodes_in_group(&"enemies"):
		if enemy is Enemy and skeleton == null:
			skeleton = enemy
		else:
			enemy.free()
	skeleton.bt_player.active = false
	skeleton.stop_moving()
	skeleton.global_position = Vector3(20, 0.25, 20)
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	return [tree, state, player, skeleton]


func _tap(tree: SceneTree, action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await tree.physics_frame
	var release := InputEventAction.new()
	release.action = action
	Input.parse_input_event(release)
	await tree.physics_frame


func _lift(tree: SceneTree, player: PlayerCharacter, thing: Node3D) -> void:
	player.global_position = thing.global_position + Vector3(0, 0, 1.0)
	player.model.look_at(player.model.global_position + Vector3.BACK, Vector3.UP)
	for i in 3:
		await tree.physics_frame
	await _tap(tree, &"interact")
	await tree.create_timer(0.7).timeout


func test_lift_a_pot_and_throw_it_to_break() -> void:
	var setup: Array = await _setup()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[2]
	var pot: Breakable = tree.current_scene.get_node(^"Pot1")
	await _lift(tree, player, pot)
	assert_eq(player.movement_state.get_active_state().name, &"Carrying", "interactuar la levanta")
	assert_true(player.carrier.is_carrying() and pot.get_parent() is ThrownObject, "sobre la cabeza")
	await _tap(tree, &"interact")
	await tree.create_timer(1.2).timeout
	assert_eq(is_instance_valid(pot), false, "al caer se rompe")
	assert_eq(player.movement_state.get_active_state().name, &"Idle")
	setup[1].reset()


func test_thrown_pot_hurts_an_enemy() -> void:
	var setup: Array = await _setup()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[2]
	var skeleton: Enemy = setup[3]
	var pot: Breakable = tree.current_scene.get_node(^"Pot1")
	await _lift(tree, player, pot)
	skeleton.global_position = player.global_position + Vector3(0, 0, -3.0)
	skeleton.health.invulnerability_time = 0.0
	var before := skeleton.health.current
	await _tap(tree, &"attack")
	await tree.create_timer(1.2).timeout
	assert_true(skeleton.health.current < before, "le pega (%d → %d)" % [before, skeleton.health.current])
	setup[1].reset()


func test_stone_stays_and_presses_a_switch() -> void:
	var setup: Array = await _setup()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[2]
	var stone: Node3D = STONE.instantiate()
	tree.current_scene.add_child(stone)
	stone.global_position = Vector3(6, 0.25, 6)
	var plate: FloorSwitch = FLOOR_SWITCH.instantiate()
	tree.current_scene.add_child(plate)
	plate.global_position = Vector3(6, 0.25, 6) + Vector3(0, 0, -3.5)
	await _lift(tree, player, stone)
	await _tap(tree, &"interact")
	await tree.create_timer(2.0).timeout
	assert_true(is_instance_valid(stone), "la piedra no se rompe")
	var landed: Vector3 = stone.global_position - plate.global_position
	landed.y = 0.0
	assert_true(plate.active, "cae sobre la placa y la aprieta (quedó a %.1f m)" % landed.length())
	await _lift(tree, player, stone)
	assert_eq(player.movement_state.get_active_state().name, &"Carrying", "se puede volver a levantar")
	setup[1].reset()


func test_dodging_drops_what_it_carries() -> void:
	var setup: Array = await _setup()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[2]
	var pot: Breakable = tree.current_scene.get_node(^"Pot1")
	await _lift(tree, player, pot)
	await _tap(tree, &"dodge")
	await tree.create_timer(1.0).timeout
	assert_eq(player.carrier.is_carrying(), false, "rodar la suelta")
	assert_eq(is_instance_valid(pot), false, "y se rompe al caer")
	setup[1].reset()


func test_in_reach_it_gets_an_outline() -> void:
	var setup: Array = await _setup()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[2]
	var pot: Breakable = tree.current_scene.get_node(^"Pot1")
	var model := pot.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	player.global_position = pot.global_position + Vector3(0, 0, 6.0)
	for i in 3:
		await tree.physics_frame
	assert_eq(model.material_overlay, Liftable.STENCIL_MARK, "lejos, sin contorno: solo marca el stencil (no hace silueta al player)")
	player.global_position = pot.global_position + Vector3(0, 0, 1.0)
	player.model.look_at(player.model.global_position + Vector3.BACK, Vector3.UP)
	for i in 3:
		await tree.physics_frame
	assert_true(model.material_overlay != Liftable.STENCIL_MARK and model.material_overlay.next_pass == Liftable.STENCIL_MARK, "al alcance, con contorno, y sigue marcando el stencil")
	await _tap(tree, &"interact")
	await tree.create_timer(0.7).timeout
	assert_true(model.material_overlay is ShaderMaterial and model.material_overlay.next_pass is ShaderMaterial and (model.material_overlay.next_pass as ShaderMaterial).shader == preload("res://src/feel/occluded_silhouette.gdshader"), "levantada, sin contorno: con el destello y la silueta del player")
	setup[1].reset()
