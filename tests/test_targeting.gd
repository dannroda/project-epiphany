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


func test_right_stick_jumps_once_per_flick() -> void:
	var setup: Array = await _load()
	var tree: SceneTree = setup[0]
	var targeting: Targeting = setup[1]
	targeting.lock_best_target()
	Input.action_press(&"look_right", 1.0)
	for i in 5:
		await tree.physics_frame
	assert_eq(_name(targeting), "Right", "un salto aunque el stick siga apretado")
	Input.action_release(&"look_right")
	await tree.physics_frame
	Input.action_press(&"look_left", 1.0)
	await tree.physics_frame
	await tree.physics_frame
	Input.action_release(&"look_left")
	assert_eq(_name(targeting), "Middle")
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
