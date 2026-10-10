extends "res://tests/test_case.gd"

const LEVEL := "res://levels/test.tscn"
const SHIELD_SKELETON := preload("res://src/entities/shield_skeleton.tscn")


func _setup() -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.get_node(^"GameState").reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	for enemy in tree.get_nodes_in_group(&"enemies"):
		enemy.free()
	var skeleton: Enemy = SHIELD_SKELETON.instantiate()
	skeleton.position = Vector3(0, 0.25, -4)
	tree.current_scene.add_child(skeleton)
	skeleton.bt_player.active = false
	await tree.physics_frame
	skeleton.look_at(skeleton.global_position - Vector3.BACK, Vector3.UP)
	skeleton.health.invulnerability_time = 0.0
	var attacker := Node3D.new()
	tree.current_scene.add_child(attacker)
	return [tree, skeleton, attacker]


func _hit(skeleton: Enemy, attacker: Node3D, from: Vector3, stun := 0.0, element := &"") -> int:
	attacker.global_position = skeleton.global_position + from
	var info := DamageInfo.new()
	info.amount = 2
	info.source = attacker
	info.team = EntityConfig.Team.PLAYER
	info.stun_time = stun
	info.element = element
	var before := skeleton.health.current
	skeleton.hurtbox.receive(info)
	return before - skeleton.health.current


func test_blocks_the_front_but_not_the_back_or_bombs() -> void:
	var setup: Array = await _setup()
	var skeleton: Enemy = setup[1]
	var attacker: Node3D = setup[2]
	assert_true(skeleton.facing().dot(Vector3.BACK) > 0.99, "mira hacia +Z")
	assert_eq(_hit(skeleton, attacker, Vector3(0, 0, 2)), 0, "de frente la espada no le hace nada")
	assert_eq(_hit(skeleton, attacker, Vector3(0, 0, -2)), 2, "por la espalda, sí")
	assert_eq(_hit(skeleton, attacker, Vector3(0, 0, 2), 0.0, &"explosive"), 2, "una bomba de frente también")
	setup[0].root.get_node(^"GameState").reset()


func test_shield_bash_lowers_the_guard_for_a_moment() -> void:
	var setup: Array = await _setup()
	var tree: SceneTree = setup[0]
	var skeleton: Enemy = setup[1]
	var attacker: Node3D = setup[2]
	assert_eq(_hit(skeleton, attacker, Vector3(0, 0, 2), 1.2), 0, "el golpe de escudo no daña")
	assert_eq(skeleton.is_guarding(), false, "pero le baja la guardia")
	assert_eq(_hit(skeleton, attacker, Vector3(0, 0, 2)), 2, "y la espada entra de frente")
	await tree.create_timer(skeleton.config.guard_break_time + 0.2).timeout
	assert_eq(_hit(skeleton, attacker, Vector3(0, 0, 2)), 0, "después vuelve a cubrirse")
	tree.root.get_node(^"GameState").reset()


func test_turns_slowly_so_you_can_roll_behind() -> void:
	var setup: Array = await _setup()
	var tree: SceneTree = setup[0]
	var skeleton: Enemy = setup[1]
	skeleton.face_towards(skeleton.global_position + Vector3.FORWARD)
	for i in 6:
		await tree.physics_frame
	assert_true(skeleton.facing().dot(Vector3.BACK) > 0.5, "en 0,1 s todavía casi no giró")
	await tree.create_timer(1.6).timeout
	assert_true(skeleton.facing().dot(Vector3.FORWARD) > 0.95, "termina mirando al otro lado")
	tree.root.get_node(^"GameState").reset()


func test_lowers_the_shield_while_attacking() -> void:
	var setup: Array = await _setup()
	var tree: SceneTree = setup[0]
	var skeleton: Enemy = setup[1]
	var attacker: Node3D = setup[2]
	var pose: SkeletonModifier3D = skeleton.find_child("GuardPose", true, false)
	assert_eq(pose.influence, 1.0, "de entrada, el escudo arriba")
	skeleton.anim_player.play(&"CombatMelee/Melee_1H_Attack_Chop")
	await tree.create_timer(0.25).timeout
	assert_true(pose.influence < 0.5, "al atacar baja el escudo")
	assert_eq(_hit(skeleton, attacker, Vector3(0, 0, 2)), 2, "y la espada entra de frente")
	tree.root.get_node(^"GameState").reset()
