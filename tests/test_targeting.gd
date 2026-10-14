extends "res://tests/test_case.gd"

const LEVEL := "res://levels/test_targeting.tscn"


func _load() -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.get_node(^"GameState").reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	for enemy: Enemy in tree.get_nodes_in_group(&"enemies"):
		enemy.bt_player.active = false
	for i in 10:
		await tree.physics_frame
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	return [tree, player.targeting, tree.current_scene]


func _name(targeting: Targeting) -> String:
	return String(targeting.current.name) if targeting.current else "-"


func test_cycle_between_skeletons_in_a_row() -> void:
	var setup: Array = await _load()
	var targeting: Targeting = setup[1]
	var level: Node = setup[2]
	var names := targeting.valid_candidates(targeting.get_viewport().get_camera_3d()).map(func(c: Node) -> String: return String(c.name))
	assert_eq(names.has("Hidden"), false, "el de atrás de la pared no se puede fijar")
	assert_eq(names.size(), 3)
	targeting.lock_best_target()
	assert_eq(_name(targeting), "Middle", "el más centrado")
	targeting.cycle(Vector2.RIGHT)
	assert_eq(_name(targeting), "Right")
	targeting.cycle(Vector2.RIGHT)
	assert_eq(_name(targeting), "Right", "sin wrap no pasa nada")
	targeting.cycle(Vector2.LEFT)
	targeting.cycle(Vector2.LEFT)
	assert_eq(_name(targeting), "Left", "en orden")
	targeting.wrap_around = true
	targeting.cycle(Vector2.LEFT)
	assert_eq(_name(targeting), "Right", "con wrap salta al otro extremo")
	targeting.clear()


func _stick(x: float, y: float) -> void:
	for pair in [[JOY_AXIS_RIGHT_X, x], [JOY_AXIS_RIGHT_Y, y]]:
		var motion := InputEventJoypadMotion.new()
		motion.axis = pair[0]
		motion.axis_value = pair[1]
		Input.parse_input_event(motion)


func test_right_stick_points_at_target() -> void:
	var setup: Array = await _load()
	var tree: SceneTree = setup[0]
	var targeting: Targeting = setup[1]
	targeting.lock_best_target()
	assert_eq(_name(targeting), "Middle")
	_stick(-0.6, -0.8)
	for i in 3:
		await tree.physics_frame
	assert_eq(_name(targeting), "Left", "apunta arriba a la izquierda: el de la izquierda, aunque no sea el vecino")
	_stick(0.6, -0.8)
	for i in 3:
		await tree.physics_frame
	assert_eq(_name(targeting), "Right", "de Left a Right directo, sin pasar por Middle")
	_stick(0.0, -1.0)
	for i in 3:
		await tree.physics_frame
	assert_eq(_name(targeting), "Middle", "apunta al frente")
	_stick(0.0, 0.0)
	await tree.physics_frame
	targeting.clear()


func test_dead_target_released_after_grace() -> void:
	var setup: Array = await _load()
	var tree: SceneTree = setup[0]
	var targeting: Targeting = setup[1]
	targeting.lock_best_target()
	var target := targeting.current as Enemy
	target.health.invulnerability_time = 0.0
	target.health.damage(100)
	await tree.physics_frame
	assert_eq(targeting.current, target, "todavía fijado durante el margen")
	await tree.create_timer(0.6).timeout
	assert_eq(targeting.current, null, "soltado después del margen")
	targeting.lock_mode = Targeting.LockMode.TOGGLE
	targeting.lock_best_target()
	var second := targeting.current as Enemy
	second.health.invulnerability_time = 0.0
	second.health.damage(100)
	await tree.create_timer(0.6).timeout
	assert_true(targeting.current != null and targeting.current != second, "en modo alternar salta al siguiente")
	targeting.lock_mode = Targeting.LockMode.HOLD
	targeting.clear()


func test_range_is_the_detector_radius() -> void:
	var setup: Array = await _load()
	var tree: SceneTree = setup[0]
	var targeting: Targeting = setup[1]
	var level: Node = setup[2]
	var radius := targeting.targeting_range
	assert_eq(radius, (targeting.detector_shape.shape as CylinderShape3D).radius)
	var player := targeting.player
	var middle := level.get_node(^"Middle") as Enemy
	middle.global_position = player.global_position + Vector3(0, 0, -(radius - 0.5))
	await tree.physics_frame
	targeting.set_target(middle)
	for i in 60:
		await tree.physics_frame
	assert_eq(_name(targeting), "Middle", "dentro del radio sigue fijado")
	middle.global_position = player.global_position + Vector3(0, 0, -(radius + 1.0))
	for i in 60:
		await tree.physics_frame
	assert_eq(_name(targeting), "-", "fuera del radio se suelta")


func test_locking_picks_the_nearest_enemy() -> void:
	var setup: Array = await _load()
	var tree: SceneTree = setup[0]
	var targeting: Targeting = setup[1]
	var level: Node = setup[2]
	var right := level.get_node(^"Right") as Node3D
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	player.global_position = right.global_position + Vector3(0, 0, 2.5)
	await tree.physics_frame
	targeting.lock_best_target()
	assert_eq(_name(targeting), "Right", "al fijar, el enemigo más cercano y no el más centrado")
