extends "res://tests/test_case.gd"
## El Centinela de la Necrópolis (11.192): mini jefe del overworld con dos esqueletos; vencidos todos, aparece el martillo.

const LEVEL := "res://levels/overworld.tscn"

var tree: SceneTree
var level: Node
var player: PlayerCharacter
var fight: ArenaFight
var centinela: Centinela


func _start(flags: Array[StringName] = []) -> void:
	tree = Engine.get_main_loop() as SceneTree
	tree.root.get_node(^"MenuStack").clear()
	tree.paused = false
	var state := tree.root.get_node(^"GameState")
	state.reset()
	for flag in flags:
		state.set_flag(flag, true)
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	await tree.create_timer(0.3).timeout
	level = tree.current_scene
	player = tree.get_first_node_in_group(&"player") as PlayerCharacter
	player.health.invulnerability_time = 0.0
	for enemy in tree.get_nodes_in_group(&"enemies"):
		enemy.free()
	fight = level.get_node(^"HammerFight") as ArenaFight
	centinela = fight.get_node_or_null(^"Centinela") as Centinela
	TopDownCamera.unlock_reveals = true


func _until(done: Callable, seconds := 8.0) -> bool:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until and not done.call():
		await tree.physics_frame
	return done.call()


func _escorts() -> Array:
	return fight.get_children().filter(func(child: Node) -> bool: return child is Enemy and not child.is_dead)


## Durante la pelea el player no muere ni sale volando de la explanada.
func _hold_player(at: Vector3) -> Callable:
	var hold := func() -> void:
		player.health.reset(player.health.max_health)
		player.global_position = at
	tree.physics_frame.connect(hold)
	return hold


func test_the_sentinel_falls_with_its_escort_and_leaves_the_hammer() -> void:
	await _start()
	centinela.stuck_time = 6.0
	assert_eq(_escorts(), [], "antes de la pelea no hay esqueletos")
	var hold := _hold_player(fight.global_position + Vector3(0, 0, 4))
	assert_true(await _until(func() -> bool: return centinela.state != Centinela.State.IDLE), "al entrar a la explanada arranca la pelea")
	assert_eq(_escorts().size(), 2, "aparecen los dos esqueletos")
	centinela.hurtbox.receive(DamageInfo.make(2, 0.0, player))
	assert_eq(centinela.health.current, centinela.health.max_health, "de pie, la espada rebota en la piedra")
	while not centinela.is_dead:
		assert_true(await _until(func() -> bool: return centinela.state == Centinela.State.STUCK, 20.0), "baja la maza y queda clavada")
		while not centinela.is_dead and centinela.is_vulnerable():
			centinela.hurtbox.receive(DamageInfo.make(4, 0.0, player))
			await tree.create_timer(0.3).timeout
	assert_true(not fight.active, "con los esqueletos en pie la pelea sigue")
	assert_true(fight.reward.get_parent() == null, "y el martillo no aparece")
	for escort in _escorts():
		(escort as Enemy).health.damage(999)
	assert_true(await _until(func() -> bool: return fight.active), "vencidos todos, pelea ganada")
	tree.physics_frame.disconnect(hold)
	assert_eq(tree.root.get_node(^"GameState").get_flag(&"ow_hammer_guard"), true, "queda el flag")
	assert_true(fight.reward.is_inside_tree(), "aparece el martillo")
	var pedestal := fight.get_node(^"Pedestal") as Node3D
	assert_true(fight.reward.global_position.y > pedestal.global_position.y + 0.8, "sobre el pedestal")
	var state := tree.root.get_node(^"GameState")
	player.global_position = pedestal.global_position + Vector3(0, 0, 1.4)
	assert_true(await _until(func() -> bool: return state.inventory.has(&"hammer")), "se lleva el martillo")
	assert_eq(state.get_flag(&"ow_hammer_taken"), true, "tomado")
	tree.root.get_node(^"MenuStack").clear()
	await tree.create_timer(0.6).timeout
	state.reset()


func test_leaving_the_esplanade_resets_the_fight() -> void:
	await _start()
	player.global_position = fight.global_position + Vector3(0, 0, 4)
	assert_true(await _until(func() -> bool: return centinela.state != Centinela.State.IDLE), "arranca la pelea")
	player.global_position = fight.global_position + Vector3(0, 0, 14)
	assert_true(await _until(func() -> bool: return centinela.state == Centinela.State.IDLE, 3.0), "fuera de la explanada vuelve a esperar")
	assert_true(await _until(func() -> bool: return _escorts().is_empty(), 2.0), "y los esqueletos se van")
	player.global_position = fight.global_position + Vector3(0, 0, 4)
	assert_true(await _until(func() -> bool: return _escorts().size() == 2), "al volver aparecen de nuevo")
	tree.root.get_node(^"GameState").reset()


func test_won_the_hammer_waits_on_its_spot() -> void:
	await _start([&"ow_hammer_guard"])
	assert_true(fight.active, "ganada queda ganada")
	assert_true(not is_instance_valid(centinela) or centinela.is_queued_for_deletion(), "sin Centinela")
	assert_true(fight.reward.is_inside_tree(), "el martillo espera")
	await _start([&"ow_hammer_guard", &"ow_hammer_taken"])
	assert_true(fight.reward == null or not fight.reward.is_inside_tree(), "tomado, no vuelve")
	tree.root.get_node(^"GameState").reset()
