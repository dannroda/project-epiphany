extends "res://tests/test_case.gd"

const LEVEL := "res://levels/test.tscn"


func _load_level() -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.get_node(^"GameState").reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	var enemy := tree.get_first_node_in_group(&"enemies") as Enemy
	for i in 300:
		if player.movement_state.get_active_state().name == &"Idle":
			break
		await tree.physics_frame
	return [tree, player, enemy]


func _frames(tree: SceneTree, count: int) -> void:
	for i in count:
		await tree.physics_frame


func test_chases_and_hits_the_player() -> void:
	var setup: Array = await _load_level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var enemy: Enemy = setup[2]
	player.global_position = enemy.global_position - Vector3(0, 0, 5)
	var start_distance := player.global_position.distance_to(enemy.global_position)
	var start_health := player.health.current
	var closest := start_distance
	for i in 400:
		await tree.physics_frame
		closest = minf(closest, player.global_position.distance_to(enemy.global_position))
		if player.health.current < start_health:
			break
	assert_true(closest < start_distance - 2.0, "se acercó (%.1f → %.1f)" % [start_distance, closest])
	assert_true(player.health.current < start_health, "le pegó al player")


func test_hit_during_windup_cancels_attack() -> void:
	var setup: Array = await _load_level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var enemy: Enemy = setup[2]
	player.global_position = enemy.global_position - Vector3(0, 0, 1.2)
	var attacking := false
	for i in 120:
		await tree.physics_frame
		if enemy.anim_player.current_animation == &"CombatMelee/Melee_1H_Attack_Chop":
			attacking = true
			break
	assert_true(attacking, "empezó el ataque")
	var info := player.config.make_damage(player)
	enemy.hurtbox.receive(info)
	await _frames(tree, 3)
	assert_eq(enemy.attack_runner.is_running(), false, "la hitbox se apagó")
	assert_eq(enemy.hitbox.active_attack, null)


func test_death_releases_lock_on() -> void:
	var setup: Array = await _load_level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var enemy: Enemy = setup[2]
	var defeated := [false]
	enemy.defeated.connect(func(_e: Enemy) -> void: defeated[0] = true)
	enemy.health.invulnerability_time = 0.0
	enemy.health.damage(100)
	await _frames(tree, 2)
	assert_eq(defeated[0], true)
	assert_eq(enemy.is_in_group(&"targetable"), false)
	await _frames(tree, 150)
	assert_eq(enemy.bt_player.active, false, "terminó de morir")
