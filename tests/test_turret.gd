extends "res://tests/test_case.gd"

const LEVEL := "res://levels/test.tscn"


func _setup(shield: StringName) -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	state.reset()
	if shield != &"shield_wood":
		state.give(Items.get_item(shield))
		state.equip(Items.get_item(shield))
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	for i in 3:
		await tree.physics_frame
	var turret: Turret = tree.current_scene.get_node(^"Turret")
	for enemy in tree.get_nodes_in_group(&"enemies"):
		if enemy != turret:
			enemy.free()
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	player.global_position = turret.global_position + Vector3(0, 0, 5)
	player.model.look_at(player.model.global_position + Vector3.BACK, Vector3.UP)
	player.health.invulnerability_time = 0.0
	hold_block(player, true)
	use_gamepad()
	return [tree, state, player, turret]


func _wait_for(tree: SceneTree, seconds: float, done: Callable) -> void:
	var until := Time.get_ticks_msec() + seconds * 1000.0
	while Time.get_ticks_msec() < until and not done.call():
		await tree.physics_frame


func test_three_reflected_orbs_destroy_it() -> void:
	var setup: Array = await _setup(&"shield_mirror")
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[2]
	var turret: Turret = setup[3]
	await _wait_for(tree, 14.0, func() -> bool: return turret.is_dead)
	assert_true(turret.is_dead, "tres orbes reflejados la destruyen")
	assert_eq(player.health.current, player.health.max_health, "el espejo no deja pasar ninguno")
	setup[1].reset()


func test_wood_shield_only_blocks() -> void:
	var setup: Array = await _setup(&"shield_wood")
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[2]
	var turret: Turret = setup[3]
	var shots: Array = []
	tree.node_added.connect(func(n: Node) -> void:
		if n is Projectile:
			shots.append(n))
	await _wait_for(tree, 7.0, func() -> bool: return shots.size() >= 3)
	await tree.create_timer(1.0).timeout
	assert_true(shots.size() >= 2, "dispara orbes")
	assert_true(shots.slice(0, 2).all(func(orb) -> bool: return not is_instance_valid(orb)), "los orbes llegan y se rompen contra el escudo")
	assert_eq(turret.health.current, turret.health.max_health, "con madera solo se bloquean")
	assert_eq(player.health.current, player.health.max_health)
	setup[1].reset()


func test_arrows_hurt_sword_does_not() -> void:
	var setup: Array = await _setup(&"shield_wood")
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[2]
	var turret: Turret = setup[3]
	turret.bt_player.active = false
	var slash := DamageInfo.new()
	slash.amount = 4
	slash.source = player
	slash.team = EntityConfig.Team.PLAYER
	turret.hurtbox.receive(slash)
	assert_eq(turret.health.current, turret.health.max_health, "la espada rebota")
	var arrow: Projectile = preload("res://src/items/arrow/arrow.tscn").instantiate()
	tree.current_scene.add_child(arrow)
	var info := Items.get_item(&"bow").make_damage(player)
	info.team = EntityConfig.Team.PLAYER
	arrow.launch(turret.global_position + Vector3(0, 1.4, 3), Vector3.FORWARD * 20.0, info)
	await tree.create_timer(0.4).timeout
	assert_eq(turret.health.current, turret.health.max_health - 2, "la flecha la daña")
	setup[1].reset()


func test_a_destroyed_turret_comes_back_when_you_leave_its_room() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.get_node(^"GameState").reset()
	tree.change_scene_to_file("res://levels/test_rooms.tscn")
	await tree.scene_changed
	var level := tree.current_scene
	level.get_node(^"Skeleton").free()
	var room: Room = level.get_node(^"RoomB")
	var turret: Turret = load("res://src/entities/turret/turret.tscn").instantiate()
	level.add_child(turret)
	var spot := room.bounds().get_center()
	turret.global_position = Vector3(spot.x, room.floor_y(), spot.y)
	for i in 3:
		await tree.physics_frame
	turret.health.damage(turret.health.current)
	assert_true(turret.is_dead, "destruida")
	room.player_left.emit(room)
	assert_true(not turret.is_dead, "al salir de su sala vuelve: un puzzle que la necesita no se traba")
	assert_true(turret.head.visible and turret.bt_player.active)
	tree.root.get_node(^"GameState").reset()


## Si revive mientras se aplasta (el player sale de la sala justo al romperla), la cabeza queda entera y visible.
func test_reviving_mid_death_keeps_the_head() -> void:
	var setup: Array = await _setup(&"shield_wood")
	var tree: SceneTree = setup[0]
	var turret: Turret = setup[3]
	turret.health.damage(turret.health.current)
	await tree.create_timer(0.1).timeout
	turret.revive()
	await tree.create_timer(0.4).timeout
	assert_true(turret.head.visible, "la cabeza se ve")
	assert_true(turret.head.scale.is_equal_approx(Vector3.ONE), "y no quedó aplastada (%s)" % turret.head.scale)
	setup[1].reset()
