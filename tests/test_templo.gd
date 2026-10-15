extends "res://tests/test_case.gd"
## El templo rediseñado (GDD §8, 11.113 y 11.182): hub con cuatro alas de puzzle y revancha, salas de 22 × 14 m.

const LEVEL := "res://levels/templo.tscn"

var tree: SceneTree
var level: Node
var player: PlayerCharacter
var camera: TopDownCamera
var state: Node


func _start() -> void:
	tree = Engine.get_main_loop() as SceneTree
	state = tree.root.get_node(^"GameState")
	state.reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	await tree.create_timer(0.3).timeout
	level = tree.current_scene
	player = tree.get_first_node_in_group(&"player") as PlayerCharacter
	player.health.invulnerability_time = 0.0
	camera = level.get_node(^"TopDownCamera") as TopDownCamera
	for enemy in tree.get_nodes_in_group(&"enemies"):
		enemy.free()


func _room(room_name: String) -> Room:
	return level.get_node("Planta/" + room_name) as Room


func _in(room_name: String, local: Vector3) -> Vector3:
	var room := _room(room_name)
	return Vector3(room.global_position.x, 0, room.global_position.z) + local


func _node(node_name: String) -> Node:
	return level.get_node("Planta/" + node_name)


func _drop(at: Vector3) -> void:
	player.global_position = at
	player.velocity = Vector3.ZERO
	var until := Time.get_ticks_msec() + 4000
	var airborne := false
	while Time.get_ticks_msec() < until and not (airborne and player.is_on_floor() and camera.room and camera.room.contains(player.global_position)):
		await tree.physics_frame
		airborne = airborne or not player.is_on_floor()
	await tree.create_timer(0.2).timeout


func _until(condition: Callable, seconds := 5.0) -> bool:
	var until := Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < until:
		if condition.call():
			return true
		await tree.physics_frame
	return false


func _arrow(eye: EyeSwitch) -> void:
	var arrow := Projectile.new()
	eye.hurtbox.receive(DamageInfo.make(2, 0.0, arrow))
	arrow.free()


func _feather() -> void:
	state.give(Items.get_item(&"feather"))
	state.assign_button(1, &"feather")


func _jump(action: StringName) -> void:
	for pressed in [true]:
		var walk := InputEventAction.new()
		walk.action = action
		walk.pressed = pressed
		walk.strength = 1.0
		Input.parse_input_event(walk)
	await tree.physics_frame
	var event := InputEventAction.new()
	event.action = &"item_2"
	event.pressed = true
	Input.parse_input_event(event)
	var release := InputEventAction.new()
	release.action = &"item_2"
	Input.parse_input_event(release)
	for i in 90:
		await tree.physics_frame
		if i > 5 and player.movement_state.get_active_state().name != &"Jumping":
			break
	var stop := InputEventAction.new()
	stop.action = action
	Input.parse_input_event(stop)
	for i in 10:
		await tree.physics_frame


func test_fourteen_rooms_of_22_by_14() -> void:
	await _start()
	var rooms := level.find_children("*", "Room", true, false)
	assert_eq(rooms.size(), 14, "catorce salas")
	for room: Room in rooms:
		var size := room.bounds().size
		assert_eq(size, Vector2(22, 14), "%s mide 22 × 14 (11.180)" % room.name)
	assert_eq(camera.room, _room("Vestibulo"), "se entra al vestíbulo")
	state.reset()


func test_the_vestibule_block_opens_the_hub() -> void:
	await _start()
	var block := _node("VestibuleBlock") as PushBlock
	var door := _node("VestibuleDoor") as Door
	assert_true(not door.is_open)
	for dir in [Vector3.RIGHT, Vector3.RIGHT, Vector3.RIGHT, Vector3.RIGHT, Vector3.FORWARD]:
		assert_true(block.try_push(dir), "el bloque avanza")
		await tree.create_timer(0.6).timeout
	assert_true(await _until(func() -> bool: return door.is_open), "en el interruptor se abre la puerta del hub")
	state.reset()


func test_the_feather_wing_pits_and_compass() -> void:
	await _start()
	_feather()
	await _drop(_in("Pluma", Vector3(5, 0.5, 0)))
	assert_eq(camera.room, _room("Pluma"))
	var health := player.health.current
	await tree.create_timer(0.8).timeout
	await _drop(_in("Pluma", Vector3(2, 0.5, -2)))
	await tree.create_timer(1.5).timeout
	assert_eq(camera.room, _room("Pluma"), "el hueco devuelve a la sala")
	assert_eq(player.health.current, health - 2, "y lastima")
	for spikes: SpikeTrap in level.find_children("PlumaSpikes_*", "", true, false):
		spikes.process_mode = Node.PROCESS_MODE_DISABLED
	player.global_position = _in("Pluma", Vector3(4, 0.5, 0))
	await tree.create_timer(0.4).timeout
	await _jump(&"move_left")
	await _jump(&"move_left")
	assert_true(player.global_position.x < _in("Pluma", Vector3(-2.5, 0, 0)).x, "con la pluma cruza las dos filas (%s)" % player.global_position.snappedf(0.1))
	assert_true((_node("CompassChest") as Node3D).global_position.x < _in("Pluma", Vector3(-2.5, 0, 0)).x, "la brújula espera del otro lado")
	state.reset()


func test_the_bow_wing_eyes_over_the_abyss_open_the_arena() -> void:
	await _start()
	var door := _node("BowDoor") as Door
	door.reveal_on_open = false
	var pit := _node("ArcoPit") as Node3D
	for eye_name in ["ArcoEyeW", "ArcoEyeE"]:
		assert_true((_node(eye_name) as Node3D).global_position.z < pit.global_position.z, "%s mira desde detrás del abismo" % eye_name)
	_arrow(_node("ArcoEyeW") as EyeSwitch)
	await tree.create_timer(0.5).timeout
	assert_true(not door.is_open, "con un ojo sigue cerrada")
	_arrow(_node("ArcoEyeE") as EyeSwitch)
	assert_true(await _until(func() -> bool: return door.is_open, 3.0), "los dos ojos abren la arena del arco")
	state.reset()


func test_each_wing_ends_in_a_rematch_that_gives_a_boss_key_piece() -> void:
	await _start()
	for spec: Array in [["FeatherFight", "PlumaOjo", &"te_eye_feather", "FeatherKeyChest"], ["BowFight", "ArcoOjo", &"te_eye_bow", "BowKeyChest"],
			["HookFight", "GanchoOjo", &"te_eye_hook", ""], ["MirrorFight", "EspejoOjo", &"te_eye_mirror", ""]]:
		var fight := _node(spec[0]) as ArenaFight
		assert_true(fight.rematch, "%s es revancha" % spec[0])
		assert_eq(fight.room, _room(spec[1]))
		assert_eq(fight.flag, spec[2])
		assert_eq(fight.reward.item.id, &"boss_key_piece", "%s da una pieza de la llave" % spec[0])
		assert_eq(fight.doors.size(), 1, "%s cierra su puerta" % spec[0])
		assert_true(_node("HubSeal").switches.has(NodePath("../" + spec[0])), "%s enciende un ojo del sello" % spec[0])
		if spec[3]:
			assert_eq((_node(spec[3]) as Chest).switches, [NodePath("../" + spec[0])] as Array[NodePath], "%s aparece al ganar" % spec[3])
	state.reset()


func test_a_rematch_closes_its_door_and_starts_at_half_health() -> void:
	tree = Engine.get_main_loop() as SceneTree
	state = tree.root.get_node(^"GameState")
	state.reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	await tree.create_timer(0.3).timeout
	level = tree.current_scene
	player = tree.get_first_node_in_group(&"player") as PlayerCharacter
	camera = level.get_node(^"TopDownCamera") as TopDownCamera
	player.health.reset(80)
	var fight := _node("FeatherFight") as ArenaFight
	var mallqui := fight.get_node(^"Mallqui")
	await _drop(_in("PlumaOjo", Vector3(-8, 0.5, 0)))
	assert_eq(camera.room, _room("PlumaOjo"))
	assert_true(await _until(func() -> bool: return not (_node("FeatherDoor") as Door).is_open, 5.0), "se cierra la puerta de la arena")
	assert_true(await _until(func() -> bool: return fight.started and not fight.in_intro and mallqui.health.current < mallqui.health.max_health, 10.0), "arranca la revancha")
	assert_eq(mallqui.health.current, ceili(mallqui.health.max_health / 2.0), "el Mallqui vuelve con media vida")
	assert_eq(fight.bar_fraction(), 1.0, "la barra cuenta desde ahí")
	state.reset()


func _hook_to(post: HookPost) -> void:
	player.targeting.set_target(post)
	var press := InputEventAction.new()
	press.action = &"item_1"
	press.pressed = true
	Input.parse_input_event(press)
	await tree.physics_frame
	var release := InputEventAction.new()
	release.action = &"item_1"
	Input.parse_input_event(release)
	for i in 180:
		await tree.physics_frame
		if i > 3 and player.movement_state.get_active_state().name != &"Hooking":
			break
	await tree.create_timer(0.3).timeout
	player.targeting.clear()


func test_the_hook_wing_abyss_is_crossed_only_with_the_hookshot() -> void:
	await _start()
	var grid := level.get_node(^"Planta/GridMap") as GridMap
	var center := grid.local_to_map(grid.to_local(_in("Gancho", Vector3.ZERO)))
	var holes := range(center.x - 6, center.x + 7).filter(func(x: int) -> bool: return grid.get_cell_item(Vector3i(x, 0, center.z)) == 10)
	assert_eq(holes.size(), 4, "el abismo mide 4 celdas: el salto largo cruza 3")
	state.give(Items.get_item(&"hookshot"))
	state.assign_button(0, &"hookshot")
	var west := _node("GanchoWestPost") as HookPost
	var east := _node("GanchoEastPost") as HookPost
	for spec: Array in [[_in("Gancho", Vector3(4.4, 0.2, -2)), west], [_in("Gancho", Vector3(-6, 0.2, 2)), east]]:
		await _drop(spec[0])
		var health := player.health.current
		var post: HookPost = spec[1]
		assert_true(post in player.targeting.possible_targets, "%s está al alcance" % post.name)
		await _hook_to(post)
		assert_true(player.global_position.distance_to(post.global_position) < 1.5 and player.health.current == health, "el gancho cruza hasta %s (%s)" % [post.name, player.global_position.snappedf(0.1)])
	assert_eq(camera.room, _room("Gancho"), "sin salir de la sala")
	state.reset()


func test_the_four_rematches_open_the_seal() -> void:
	await _start()
	var seal := _node("HubSeal") as Door
	seal.reveal_on_open = false
	for fight_name in ["FeatherFight", "BowFight", "HookFight"]:
		(_node(fight_name) as ArenaFight)._win(false)
	await tree.create_timer(0.5).timeout
	assert_true(not seal.is_open, "con tres revanchas sigue cerrado")
	assert_true(state.get_flag(&"te_eye_hook") == true, "cada revancha ganada queda ganada")
	(_node("MirrorFight") as ArenaFight)._win(false)
	assert_true(await _until(func() -> bool: return seal.is_open, 3.0), "con las cuatro se abre la antesala")
	state.reset()


func test_the_combined_room_is_three_waves_with_mini_sub_bosses_and_the_golden_sword() -> void:
	await _start()
	var spawner := _node("CombinedWaves") as WaveSpawner
	var chest := _node("CombinedChest") as Chest
	var door := _node("CombinedDoor") as Door
	assert_eq(spawner.waves().size(), 3, "tres oleadas")
	assert_true(not chest.visible, "sin cofre hasta vencerlas")
	assert_true(chest.big and chest.item.id == &"sword_golden", "cofre grande con la espada dorada")
	door.open(false)
	spawner.wave = 1
	spawner.start()
	await tree.create_timer(0.3).timeout
	assert_true(not door.is_open, "la puerta se cierra durante las oleadas")
	spawner.wave = 1
	spawner._next_wave()
	await tree.create_timer(0.5).timeout
	var mummy: Node3D = spawner._alive.filter(func(enemy: Node3D) -> bool: return enemy is MummyGuard)[0]
	assert_true(mummy.state != MummyGuard.State.IDLE, "la momia mini pelea sola en la oleada")
	assert_true(mummy.scale.x < 1.0 and mummy.health.max_health < 12, "y es chica")
	for enemy: Node3D in spawner._alive.duplicate():
		enemy.health.damage(999)
	assert_true(await _until(func() -> bool: return chest.visible, 6.0), "vencida la tercera aparece el cofre")
	assert_true(door.is_open, "y se abre la puerta")
	assert_true(state.get_flag(&"te_combined_waves") == true)
	state.reset()


func test_getting_the_golden_sword_equips_it_with_its_trail() -> void:
	await _start()
	var before := player.sword_trail.color_gradient
	state.give(Items.get_item(&"sword_golden"))
	await tree.process_frame
	assert_eq(player.equipment.weapon.id, &"sword_golden", "se equipa sola")
	assert_eq(player.sword_trail.color_gradient, Items.get_item(&"sword_golden").trail, "estela dorada")
	state.equip(Items.get_item(&"sword_basic"))
	await tree.process_frame
	assert_eq(player.sword_trail.color_gradient, before, "con la común vuelve la de siempre")
	state.reset()


func test_the_boss_uses_the_temple_flags() -> void:
	await _start()
	var arena := level.get_node(^"BossArena")
	assert_eq(arena.defeated_flag, &"te_boss_defeated")
	assert_eq((level.get_node(^"BossExitPortal") as Portal).required_flag, &"te_boss_defeated")
	assert_true(_room("Jefe").boss_room)
	state.reset()


func test_the_hand_fights_and_opens_the_combined_room() -> void:
	await _start()
	var fight := _node("ManoFight") as ArenaFight
	var guard := fight.get_node(^"Hand") as HandGuard
	player.health.reset(80)
	await _drop(_in("Mano", Vector3(0, 0.5, 2)))
	assert_eq(camera.room, _room("Mano"))
	assert_true(await _until(func() -> bool: return guard.hand.striking, 15.0), "la Mano ataca")
	assert_true(not (_node("HandDoor") as Door).is_open, "se cierra la puerta")
	assert_true(not (_node("CombinedDoor") as Door).is_open, "la combinada sigue cerrada")
	var before := guard.health.current
	await _until(func() -> bool: return guard.hand.state == BossHand.State.READY, 15.0)
	guard.hand.hurtbox.receive(DamageInfo.make(2, 0.0, player))
	assert_eq(guard.health.current, before, "lista, la espada rebota")
	while not guard.is_dead:
		player.health.reset(80)
		if guard.hand.state == BossHand.State.STUNNED:
			guard.hand.hurtbox.receive(DamageInfo.make(2, 0.0, player))
			await tree.create_timer(0.35).timeout
		else:
			await tree.physics_frame
	assert_true(await _until(func() -> bool: return fight.active, 4.0), "pelea ganada")
	assert_true(state.get_flag(&"te_hand_defeated") == true)
	assert_true(await _until(func() -> bool: return (_node("CombinedDoor") as Door).is_open, 4.0), "se abre la sala combinada")
	state.reset()


func test_every_room_that_spends_ammo_has_pots_that_always_give_it() -> void:
	await _start()
	state.give(Items.get_item(&"bomb_bag"))
	state.give(Items.get_item(&"bow"))
	var rng := RandomNumberGenerator.new()
	for spot: Array in [["ArcoBombPot1", &"Arco", &"bomb"], ["ArcoBombPot2", &"Arco", &"bomb"],
			["ArcoOjoArrowPot1", &"ArcoOjo", &"arrow"], ["ArcoOjoArrowPot2", &"ArcoOjo", &"arrow"],
			["CombinedBombPot", &"Combinada", &"bomb"], ["CombinedArrowPot", &"Combinada", &"arrow"]]:
		var pot := level.get_node("Planta/" + spot[0]) as Node3D
		assert_true(_room(spot[1]).contains(pot.global_position), "%s está en %s" % [spot[0], spot[1]])
		for i in 20:
			var entry: DropEntry = pot.drops.roll(rng)
			assert_true(entry != null and entry.item != null and entry.item.id == spot[2], "%s siempre da %s" % [spot[0], spot[2]])
	state.reset()


func _scenario(scenario: String) -> void:
	tree = Engine.get_main_loop() as SceneTree
	state = tree.root.get_node(^"GameState")
	state.reset()
	assert_eq(await tree.root.get_node(^"SaveManager").load_scenario(scenario), OK)
	level = tree.current_scene
	player = tree.get_first_node_in_group(&"player") as PlayerCharacter
	while player.movement_state.get_active_state().name == &"Spawning":
		await tree.physics_frame
	await tree.create_timer(0.2).timeout
	player.health.invulnerability_time = 0.0
	camera = level.get_node(^"TopDownCamera") as TopDownCamera


func test_the_boss_door_needs_its_key() -> void:
	await _scenario("pre_boss")
	state.current_dungeon_state().has_boss_key = false
	var door := _node("BossDoor") as Door
	door.interactable.interact(player)
	assert_true(not door.is_open, "sin la llave del jefe no abre")
	var stack: Node = tree.root.get_node(^"MenuStack")
	while stack.is_open():
		stack.pop()
	state.reset()


func test_dying_to_the_boss_returns_to_the_antechamber_with_its_door_open() -> void:
	await _scenario("pre_boss")
	assert_eq(camera.room, _room("Antesala"), "pre_boss arranca en la antesala")
	var door := _node("BossDoor") as Door
	door.interactable.interact(player)
	assert_true(door.is_open, "la llave del jefe abre su puerta")
	assert_true(state.current_dungeon_state().has_boss_key, "sin gastarla")
	await tree.create_timer(0.8).timeout
	player.global_position = _in("Jefe", Vector3(0, 0, 5))
	assert_true(await _until(func() -> bool: return camera.room == _room("Jefe"), 3.0), "entra a la sala del jefe")
	player.health.damage(100)
	var stack: Node = tree.root.get_node(^"MenuStack")
	assert_true(await _until(func() -> bool: return stack.top() is GameOver, 8.0), "game over")
	(stack.top() as GameOver)._continue.pressed.emit()
	await _until(func() -> bool:
		var next := tree.get_first_node_in_group(&"player") as PlayerCharacter
		return tree.current_scene != level and next != null and not next.is_dead, 8.0)
	await tree.create_timer(1.0).timeout
	level = tree.current_scene
	camera = level.get_node(^"TopDownCamera") as TopDownCamera
	assert_eq(camera.room, _room("Antesala"), "morir contra el jefe devuelve a la antesala")
	assert_true((_node("BossDoor") as Door).is_open, "con la puerta del jefe abierta")
	state.reset()


func test_the_mirror_rematch_is_the_apu_with_the_suns_already_lit() -> void:
	tree = Engine.get_main_loop() as SceneTree
	state = tree.root.get_node(^"GameState")
	state.reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	await tree.create_timer(0.3).timeout
	level = tree.current_scene
	player = tree.get_first_node_in_group(&"player") as PlayerCharacter
	camera = level.get_node(^"TopDownCamera") as TopDownCamera
	player.health.reset(80)
	var fight := _node("MirrorFight") as ArenaFight
	var apu := fight.get_node(^"ApuKuntur") as Kuntur
	assert_true(apu.apu, "la revancha del espejo es el Apu Kuntur")
	var beam := _node("MirrorSunWest").get_node(^"Beam") as LightBeam
	assert_true(not beam.visible, "los soles esperan la pelea")
	await _drop(_in("EspejoOjo", Vector3(-8, 0.5, 0)))
	assert_true(await _until(func() -> bool: return beam.visible and not beam.segments.is_empty(), 15.0), "con media vida de entrada, enciende los soles")
	state.reset()
