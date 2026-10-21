extends "res://tests/test_case.gd"

const LEVEL := "res://levels/test/test.tscn"
const PROJECTILE := preload("res://src/entities/projectile.tscn")


func _setup() -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	state.reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	for i in 3:
		await tree.physics_frame
	var enemies := tree.get_nodes_in_group(&"enemies")
	var shooter := enemies[0] as Enemy
	for enemy in enemies.slice(1):
		enemy.free()
	shooter.bt_player.active = false
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	player.global_position = Vector3(10, 0.25, 10)
	shooter.global_position = Vector3(10, 0.25, 4)
	player.model.look_at(player.model.global_position + Vector3.BACK, Vector3.UP)
	player.health.invulnerability_time = 0.0
	for i in 3:
		await tree.physics_frame
	return [tree, state, player, shooter]


func _fire(tree: SceneTree, shooter: Enemy, player: PlayerCharacter) -> Projectile:
	var info := shooter.config.make_damage(shooter)
	info.reflectable = true
	var orb: Projectile = PROJECTILE.instantiate()
	tree.current_scene.add_child(orb)
	var from := shooter.global_position + Vector3(0, 1.1, 1.0)
	orb.launch(from, (player.global_position + Vector3.UP * 1.1 - from).normalized() * 12.0, info)
	return orb


func _guard(player: PlayerCharacter, on: bool) -> void:
	hold_block(player, on)


func test_wood_shield_blocks() -> void:
	var setup: Array = await _setup()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[2]
	_guard(player, true)
	var orb := _fire(tree, setup[3], player)
	await tree.create_timer(1.0).timeout
	assert_eq(is_instance_valid(orb), false, "se bloquea y desaparece")
	assert_eq(player.health.current, player.health.max_health, "sin daño")
	setup[1].reset()


func test_mirror_shield_reflects_to_shooter() -> void:
	var setup: Array = await _setup()
	var tree: SceneTree = setup[0]
	var state: Node = setup[1]
	var player: PlayerCharacter = setup[2]
	var shooter: Enemy = setup[3]
	state.give(Items.get_item(&"shield_mirror"))
	state.equip(Items.get_item(&"shield_mirror"))
	_guard(player, true)
	var before := shooter.health.current
	var orb := _fire(tree, shooter, player)
	await tree.create_timer(0.6).timeout
	assert_true(is_instance_valid(orb) and orb.team == EntityConfig.Team.PLAYER, "vuelve como proyectil del player")
	await tree.create_timer(1.2).timeout
	assert_true(shooter.health.current < before, "daña al que lo disparó")
	assert_eq(player.health.current, player.health.max_health)
	state.reset()


func test_unblocked_orb_hurts_and_world_breaks_it() -> void:
	var setup: Array = await _setup()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[2]
	var orb := _fire(tree, setup[3], player)
	await tree.create_timer(1.0).timeout
	assert_true(player.health.current < player.health.max_health, "sin bloquear, daña")
	assert_eq(is_instance_valid(orb), false)
	var down: Projectile = PROJECTILE.instantiate()
	tree.current_scene.add_child(down)
	down.launch(Vector3(0, 2, -8), Vector3.DOWN * 10.0, setup[3].config.make_damage(setup[3]))
	await tree.create_timer(0.5).timeout
	assert_eq(is_instance_valid(down), false, "se rompe contra el piso")
	setup[1].reset()


func test_arrow_trail_stops_when_it_sticks() -> void:
	var setup: Array = await _setup()
	var tree: SceneTree = setup[0]
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	wall.add_child(shape)
	tree.current_scene.add_child(wall)
	wall.global_position = Vector3(-6, 1, -6)
	var arrow: Projectile = preload("res://src/items/arrow/arrow.tscn").instantiate()
	tree.current_scene.add_child(arrow)
	var info := DamageInfo.new()
	info.amount = 1
	info.team = EntityConfig.Team.PLAYER
	arrow.launch(Vector3(-6, 1, -2), Vector3(0, 0, -12), info)
	var trail: Trail3D = arrow.get_node(^"Trail")
	await tree.physics_frame
	assert_true(trail.emitting, "en vuelo deja estela")
	for i in 30:
		await tree.physics_frame
	assert_true(is_instance_valid(arrow), "quedó clavada")
	assert_true(not trail.emitting, "clavada ya no deja estela")
