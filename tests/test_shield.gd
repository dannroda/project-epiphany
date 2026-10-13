extends "res://tests/test_case.gd"

const LEVEL := "res://levels/test.tscn"
const ORB := preload("res://src/entities/projectile.tscn")


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
	var enemies := tree.get_nodes_in_group(&"enemies")
	var shooter: Enemy = null
	for enemy in enemies:
		if enemy is Enemy and shooter == null:
			shooter = enemy
		else:
			enemy.free()
	shooter.bt_player.active = false
	shooter.stop_moving()
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	player.global_position = Vector3(0, 0.25, -6)
	player.model.look_at(player.model.global_position - Vector3.RIGHT, Vector3.UP)
	player.health.invulnerability_time = 0.0
	return [tree, state, player, shooter]


func _shoot_from(tree: SceneTree, shooter: Enemy, from: Vector3, at: Vector3, reflectable: bool) -> Projectile:
	shooter.global_position = Vector3(from.x, 0.25, from.z)
	var info := shooter.config.make_damage(shooter)
	info.reflectable = reflectable
	var orb: Projectile = ORB.instantiate()
	tree.current_scene.add_child(orb)
	var start := from + Vector3.UP * 1.3
	orb.launch(start, (at + Vector3.UP * 1.3 - start).normalized() * 12.0, info)
	return orb


func test_wood_shield_on_back_stops_arrows_from_behind_only() -> void:
	var setup: Array = await _setup(&"shield_wood")
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[2]
	var orb := _shoot_from(tree, setup[3], player.global_position - Vector3.RIGHT * 5.0, player.global_position, false)
	await tree.create_timer(0.8).timeout
	assert_eq(is_instance_valid(orb), false, "se frena en el escudo de la espalda")
	assert_eq(player.health.current, player.health.max_health, "sin daño por la espalda")
	_shoot_from(tree, setup[3], player.global_position + Vector3.BACK * 5.0, player.global_position, false)
	await tree.create_timer(0.8).timeout
	assert_true(player.health.current < player.health.max_health, "de costado sí lastima")
	setup[1].reset()


func test_wood_shield_does_not_stop_explosions() -> void:
	var setup: Array = await _setup(&"shield_wood")
	var player: PlayerCharacter = setup[2]
	var shooter: Enemy = setup[3]
	shooter.global_position = player.global_position + Vector3.RIGHT * 1.5
	hold_block(player, true)
	var slash := shooter.config.make_damage(shooter)
	player.hurtbox.receive(slash)
	assert_eq(player.health.current, player.health.max_health, "un espadazo de frente se bloquea")
	var blast := shooter.config.make_damage(shooter)
	blast.element = &"explosive"
	player.hurtbox.receive(blast)
	assert_true(player.health.current < player.health.max_health, "una explosión pasa aunque se bloquee")
	setup[1].reset()


func test_sword_from_behind_hurts() -> void:
	var setup: Array = await _setup(&"shield_wood")
	var player: PlayerCharacter = setup[2]
	var shooter: Enemy = setup[3]
	shooter.global_position = player.global_position - Vector3.RIGHT * 1.5
	player.hurtbox.receive(shooter.config.make_damage(shooter))
	assert_true(player.health.current < player.health.max_health, "el escudo de la espalda no frena golpes cuerpo a cuerpo")
	setup[1].reset()


func test_mirror_on_back_returns_orb_to_shooter() -> void:
	var setup: Array = await _setup(&"shield_mirror")
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[2]
	var shooter: Enemy = setup[3]
	var before := shooter.health.current
	var orb := _shoot_from(tree, shooter, player.global_position - Vector3.RIGHT * 5.0, player.global_position, true)
	await tree.create_timer(0.6).timeout
	assert_true(is_instance_valid(orb) and orb.team == EntityConfig.Team.PLAYER, "el espejo de la espalda lo refleja")
	await tree.create_timer(0.8).timeout
	assert_true(shooter.health.current < before, "vuelve y daña a quien lo tiró")
	assert_eq(player.health.current, player.health.max_health)
	setup[1].reset()


func test_releasing_block_while_frozen_lowers_the_shield() -> void:
	var setup: Array = await _setup(&"shield_wood")
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[2]
	hold_block(player, true)
	await tree.physics_frame
	assert_eq(player.is_blocking(), true, "con el botón mantenido bloquea")
	var mode := player.process_mode
	player.process_mode = Node.PROCESS_MODE_DISABLED
	Input.action_release(player.controls.action(&"block"))
	await tree.physics_frame
	player.process_mode = mode
	await tree.physics_frame
	await tree.physics_frame
	assert_eq(player.is_blocking(), false, "soltar durante un hit-stop baja el escudo")


func test_the_shield_is_a_component_and_controls_are_not_a_node() -> void:
	var setup: Array = await _setup(&"shield_wood")
	var player: PlayerCharacter = setup[2]
	assert_true(player.get_node(^"Shield") == player.shield, "el escudo es un nodo de player.tscn")
	assert_eq(player.shield.item().id, &"shield_wood", "con el escudo equipado")
	assert_true(player.controls is RefCounted and player.find_children("*", "", false, false).all(func(child: Node) -> bool: return child.name != &"Controls"), "los controles no son un nodo hijo")
	setup[1].reset()
