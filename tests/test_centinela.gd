extends "res://tests/test_case.gd"
## El Centinela del Bañado (11.192): mini jefe del overworld en la playa del Bañado con dos huancas; vencidos todos, aparece el martillo.

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
	assert_eq(_escorts(), [], "antes de la pelea no hay huancas")
	var hold := _hold_player(fight.global_position + Vector3(0, 0, 4))
	assert_true(await _until(func() -> bool: return centinela.state != Centinela.State.IDLE), "al entrar a la explanada arranca la pelea")
	assert_eq(_escorts().size(), 2, "aparecen los dos huancas")
	var ring := fight.get_node(^"FireRing") as FireRing
	assert_true(await _until(func() -> bool: return ring.closed, 3.0), "se cierra el anillo de fuego")
	await tree.physics_frame
	var out := Vector3(0, 0, ring.radius + 2.0)
	assert_true(player.test_move(player.global_transform, out), "y no deja salir")
	centinela.hurtbox.receive(DamageInfo.make(2, 0.0, player))
	assert_eq(centinela.health.current, centinela.health.max_health, "de pie, la espada rebota en la piedra")
	while not centinela.is_dead:
		assert_true(await _until(func() -> bool: return centinela.state == Centinela.State.STUCK, 20.0), "baja la maza y queda clavada")
		while not centinela.is_dead and centinela.is_vulnerable():
			centinela.hurtbox.receive(DamageInfo.make(4, 0.0, player))
			await tree.create_timer(0.3).timeout
	assert_true(not fight.active, "con los huancas en pie la pelea sigue")
	assert_true(fight.reward.get_parent() == null, "y el martillo no aparece")
	for escort in _escorts():
		(escort as Enemy).health.damage(999)
	assert_true(await _until(func() -> bool: return fight.active), "vencidos todos, pelea ganada")
	assert_true(not ring.closed, "y el anillo se abre")
	tree.physics_frame.disconnect(hold)
	assert_eq(tree.root.get_node(^"GameState").get_flag(&"ow_hammer_guard"), true, "queda el flag")
	assert_true(fight.reward.is_inside_tree(), "aparece el martillo")
	var pedestal := fight.get_node(^"Pedestal") as Node3D
	assert_true(fight.reward.global_position.y > pedestal.global_position.y + 0.8, "sobre el pedestal")
	var state := tree.root.get_node(^"GameState")
	player.global_position = pedestal.global_position + Vector3(0, 0, 1.4)
	assert_true(await _until(func() -> bool: return state.inventory.has(&"hammer")), "se lleva el martillo")
	assert_eq(state.get_flag(&"ow_hammer_taken"), true, "tomado")
	var stack: Node = tree.root.get_node(^"MenuStack")
	assert_true(await _until(func() -> bool:
		if stack.is_open():
			stack.pop()
		return not stack.is_open() and player.movement_state.get_active_state().name == &"Idle"), "cierra el item get y la tarjeta")
	state.reset()


## Daniel: una vez arrancada, la pelea sigue aunque el player se aleje de la explanada.
func test_walking_away_keeps_the_fight_going() -> void:
	await _start()
	player.global_position = fight.global_position + Vector3(0, 0, 4)
	assert_true(await _until(func() -> bool: return centinela.state != Centinela.State.IDLE), "arranca la pelea")
	assert_true(await _until(func() -> bool: return _escorts().size() == 2), "con sus dos huancas")
	var hold := _hold_player(fight.global_position + Vector3(0, 0, 14))
	await tree.create_timer(2.0).timeout
	assert_true(fight.started, "lejos de la explanada sigue arrancada")
	assert_eq(_escorts().size(), 2, "y los huancas siguen")
	tree.physics_frame.disconnect(hold)
	fight._reset()
	tree.root.get_node(^"GameState").reset()


## La marca deja de seguir al player antes del golpe (lo dispara el clip windup) y el golpe cae ahí.
func test_the_mark_locks_before_the_slam() -> void:
	await _start()
	var hold := _hold_player(fight.global_position + Vector3(0, 0, 4))
	assert_true(await _until(func() -> bool: return centinela.state == Centinela.State.WINDUP, 12.0), "levanta la maza")
	assert_true(await _until(func() -> bool: return centinela._aim_locked or centinela.state != Centinela.State.WINDUP), "algo pasa en el aviso")
	assert_true(centinela._aim_locked and centinela.state == Centinela.State.WINDUP, "la marca se traba con la maza todavía arriba")
	var mark := centinela.aim_mark.global_position
	await tree.create_timer(0.2).timeout
	assert_true(centinela.aim_mark.global_position.distance_to(mark) < 0.01 or centinela.state != Centinela.State.WINDUP, "trabada no se mueve")
	tree.physics_frame.disconnect(hold)
	fight._reset()
	tree.root.get_node(^"GameState").reset()


## Daniel: pegarle desde lejos (una flecha) también arranca la pelea.
func test_a_hit_from_afar_starts_the_fight() -> void:
	await _start()
	var hold := _hold_player(fight.global_position + Vector3(0, 0, 14))
	await tree.create_timer(0.5).timeout
	assert_true(not fight.started, "lejos, espera")
	centinela.hurtbox.receive(DamageInfo.make(1, 0.0, player))
	assert_true(await _until(func() -> bool: return centinela.state != Centinela.State.IDLE), "una flecha la arranca")
	var ring := fight.get_node(^"FireRing") as FireRing
	assert_true(not ring.closed, "con el player afuera el anillo espera")
	tree.physics_frame.disconnect(hold)
	hold = _hold_player(fight.global_position + Vector3(0, 0, 4))
	assert_true(await _until(func() -> bool: return ring.closed, 3.0), "y se cierra cuando entra")
	tree.physics_frame.disconnect(hold)
	fight._reset()
	tree.root.get_node(^"GameState").reset()


func test_won_the_hammer_waits_on_its_spot() -> void:
	await _start([&"ow_hammer_guard"])
	assert_true(fight.active, "ganada queda ganada")
	assert_true(not is_instance_valid(centinela) or centinela.is_queued_for_deletion(), "sin Centinela")
	assert_true(fight.reward.is_inside_tree(), "el martillo espera")
	await _start([&"ow_hammer_guard", &"ow_hammer_taken"])
	assert_true(fight.reward == null or not fight.reward.is_inside_tree(), "tomado, no vuelve")
	tree.root.get_node(^"GameState").reset()


func test_nothing_grows_in_the_beach_esplanade() -> void:
	await _start()
	var bounds := (fight.get_node(^"Arena") as ArenaArea).bounds()
	var crowded := []
	for decor: Node in level.find_children("Decor", "", true, false):
		for piece: Node in decor.find_children("*", "Node3D", true, false):
			if piece.get_parent() is Node3D and piece.get_parent().get_parent() == decor:
				var at := (piece as Node3D).global_position
				if bounds.has_point(Vector2(at.x, at.z)):
					crowded.append(piece.name)
	assert_eq(crowded, [], "la explanada de la playa queda limpia")
	assert_true(bounds.size.x >= 14.0 and bounds.size.y >= 10.0, "y tiene lugar para pelear")


func test_the_sentinel_is_solid() -> void:
	await _start()
	player.global_position = centinela.global_position + Vector3(0, 0.1, 2.5)
	Input.action_press(&"move_forward")
	var closest := INF
	for i in 60:
		await tree.physics_frame
		var gap := player.global_position - centinela.global_position
		closest = minf(closest, Vector2(gap.x, gap.z).length())
	Input.action_release(&"move_forward")
	assert_true(closest > 1.1, "no se lo atraviesa caminando (%.2f m)" % closest)
	tree.root.get_node(^"GameState").reset()


## Las escoltas salen como estaban en el nivel, con los overrides de sus hijos (16.52), no recargadas de su escena.
func test_escorts_keep_their_instance_overrides() -> void:
	tree = Engine.get_main_loop() as SceneTree
	tree.root.get_node(^"GameState").reset()
	var original := (load(LEVEL) as PackedScene).instantiate()
	var probe := (original.get_node(^"HammerFight").get(&"escorts")[0] as Node).get_child(0)
	probe.set_meta(&"override_probe", 7)
	tree.change_scene_to_node(original)
	await tree.scene_changed
	await tree.create_timer(0.3).timeout
	level = tree.current_scene
	player = tree.get_first_node_in_group(&"player") as PlayerCharacter
	player.health.invulnerability_time = 0.0
	fight = level.get_node(^"HammerFight") as ArenaFight
	TopDownCamera.unlock_reveals = true
	var hold := _hold_player(fight.global_position + Vector3(0, 0, 4))
	assert_true(await _until(func() -> bool: return _escorts().size() == 2), "aparecen los huancas")
	var kept := _escorts().filter(func(enemy: Enemy) -> bool: return enemy.get_child(0).get_meta(&"override_probe", 0) == 7)
	assert_eq(kept.size(), 1, "la escolta trae lo que se cambió en su hijo")
	tree.physics_frame.disconnect(hold)
