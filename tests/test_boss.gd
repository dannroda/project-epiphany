extends "res://tests/test_case.gd"
## El jefe (M9): piezas sueltas que mueve el código.

const SCENE := preload("res://src/entities/boss/boss.tscn")


func _spawn() -> Boss:
	var tree := Engine.get_main_loop() as SceneTree
	var boss := SCENE.instantiate() as Boss
	tree.root.add_child(boss)
	_single_slams(boss)
	return boss


## Las pruebas miden un golpe al piso por ataque; la tanda la prueba test_a_slam_chains_its_blows.
func _single_slams(boss: Boss) -> void:
	for hand: BossHand in [boss.hand_left, boss.hand_right]:
		hand.slam_count = 1


func _frames(count: int) -> void:
	for i in count:
		await (Engine.get_main_loop() as SceneTree).process_frame


func test_pieces_and_sockets() -> void:
	var boss := _spawn()
	for path in ["Body/Mesh", "%Eye", "%OrbMuzzle", "%UpperLid", "%LowerLid", "%HandAnchorLeft", "%HandAnchorRight", "%HandRestLeft", "%HandRestRight"]:
		assert_true(boss.get_node_or_null(path) != null, "tiene %s" % path)
	assert_true(boss.orb_muzzle.get_parent() == boss.eye, "los orbes salen del ojo y giran con él")
	assert_true(boss.hand_left.get_parent() == boss and boss.hand_right.get_parent() == boss, "las manos flotan sueltas")
	assert_true(boss.hand_rest(boss.hand_left).global_position.distance_to(boss.hand_left.global_position) < 0.01, "la mano izquierda arranca en su reposo")
	assert_true(boss.hand_left.global_position.x > 0.0, "la izquierda del jefe es +X (mira a la cámara)")
	boss.free()


func test_fingers_close_gradually_into_each_pose() -> void:
	var boss := _spawn()
	var hand := boss.hand_right
	var mesh := hand.mesh
	var fist := mesh.find_blend_shape_by_name(&"puno")
	var claw := mesh.find_blend_shape_by_name(&"garra")
	assert_true(fist >= 0 and claw >= 0, "una sola malla con shape keys")
	hand.pose = BossHand.Pose.FIST
	var midway := false
	for i in 40:
		await _frames(1)
		midway = midway or (hand.grip > 0.3 and hand.grip < 0.7)
	assert_true(midway, "los dedos van cerrándose, no saltan al puño")
	assert_true(mesh.get_blend_shape_value(fist) > 0.8, "cierra el puño")
	hand.pose = BossHand.Pose.CLAW
	await _frames(40)
	assert_true(hand.grip > 0.45 and hand.grip < 0.7 and mesh.get_blend_shape_value(claw) > 0.3 and mesh.get_blend_shape_value(fist) == 0.0, "afloja a la garra (y respira)")
	hand.pose = BossHand.Pose.OPEN
	await _frames(40)
	assert_true(mesh.get_blend_shape_value(fist) == 0.0 and hand.grip < 0.2, "vuelve abierta")
	boss.free()


func test_eye_opens_and_aims() -> void:
	var boss := _spawn()
	assert_eq(boss.get_node(^"%UpperLid").rotation.x, 0.0, "arranca cerrado")
	boss.eye_open = 1.0
	assert_true(boss.get_node(^"%UpperLid").rotation.x < -1.0 and boss.get_node(^"%LowerLid").rotation.x > 1.0, "los párpados se abren hacia arriba y hacia abajo")
	var target := boss.eye.global_position + Vector3(3.0, -4.0, 6.0)
	boss.look_at_point(target)
	var aim := (boss.orb_muzzle.global_position - boss.eye.global_position).normalized()
	assert_true(aim.dot((target - boss.eye.global_position).normalized()) > 0.99, "la salida de orbes apunta al blanco")
	boss.free()


func _hit(amount: int, stun_time := 0.0, source: Node3D = null) -> DamageInfo:
	var info := DamageInfo.new()
	info.amount = amount
	info.stun_time = stun_time
	info.source = source
	info.team = EntityConfig.Team.PLAYER
	return info


func _knock_down(hand: BossHand) -> void:
	hand.health.invulnerability_time = 0.0
	hand.stun(1.0)
	hand.hurtbox.receive(_hit(hand.health.max_health))


func test_hands_only_hurt_when_stunned() -> void:
	var boss := _spawn()
	var hand := boss.hand_left
	hand.hurtbox.receive(_hit(2))
	assert_eq(hand.health.current, hand.health.max_health, "lista, el golpe rebota en el hierro")
	hand.hurtbox.receive(_hit(1, 1.5))
	assert_eq(hand.state, BossHand.State.STUNNED, "un golpe que aturde la deja aturdida")
	assert_eq(hand.health.current, hand.health.max_health, "aturdirla no le saca vida")
	hand.hurtbox.receive(_hit(2))
	assert_eq(hand.health.current, hand.health.max_health - 2, "aturdida, la espada lastima")
	hand._physics_process(2.0)
	await (Engine.get_main_loop() as SceneTree).create_timer(0.8).timeout
	assert_eq(hand.state, BossHand.State.READY, "se repone sola")
	boss.free()


func test_both_hands_down_opens_phase_two() -> void:
	var boss := _spawn()
	boss.start_fight()
	assert_eq(boss.phase(), 1)
	_knock_down(boss.hand_left)
	assert_eq(boss.hand_left.state, BossHand.State.DOWN)
	assert_eq(boss.phase(), 1, "con una mano en pie sigue la fase 1")
	_knock_down(boss.hand_right)
	assert_eq(boss.phase(), 2, "las dos manos caídas pasan a la fase 2")
	await (Engine.get_main_loop() as SceneTree).create_timer(2.0).timeout
	assert_true(is_zero_approx(boss.hand_right.rotation.z), "vuelve derecha")
	assert_true(boss.hand_left.health.is_full(), "las manos se regeneran")
	assert_eq(boss.eye_open, 1.0, "el ojo se abre")
	boss.health.invulnerability_time = 0.0
	boss.health.damage(boss.health.max_health)
	assert_eq(boss.phases.get_active_state().name, &"Defeated", "sin vida queda derrotado")
	boss.free()


func test_eye_needs_a_projectile_to_open_the_window() -> void:
	var boss := _spawn()
	var arrow := Projectile.new()
	boss.eye_hurtbox.receive(_hit(2, 0.0, arrow))
	assert_true(not boss.is_eye_stunned(), "cerrado, nada lo toca")
	boss.eye_open = 1.0
	boss.eye_hurtbox.receive(_hit(2))
	assert_eq(boss.health.current, boss.health.max_health, "abierto, la espada sola no alcanza")
	boss.eye_hurtbox.receive(_hit(2, 0.0, arrow))
	assert_true(boss.is_eye_stunned(), "una flecha (o un orbe devuelto) lo aturde")
	boss.eye_hurtbox.receive(_hit(2))
	assert_eq(boss.health.current, boss.health.max_health - 2, "aturdido, la espada lastima")
	arrow.free()
	boss.free()


func test_utility_varies_and_uses_free_pieces() -> void:
	var boss := _spawn()
	boss.rng.seed = 7
	var player := Node3D.new()
	boss.add_child(player)
	player.global_position = boss.hand_rest(boss.hand_left).global_position + Vector3(0, 0, 2)
	boss.target = player
	var last := &""
	var seen := {}
	for i in 12:
		assert_true(boss.choose_attack(1), "siempre hay un ataque")
		assert_true(boss.chosen_attack.id != last, "no repite el ataque recién hecho")
		assert_true(1 in boss.chosen_attack.phases)
		last = boss.chosen_attack.id
		seen[last] = true
	assert_true(seen.size() >= 2, "varía los ataques")
	_knock_down(boss.hand_left)
	for i in 6:
		boss.choose_attack(1)
		assert_true(boss.attacker == boss.hand_right, "una mano caída no ataca")
	_knock_down(boss.hand_right)
	assert_true(not boss.choose_attack(1), "sin manos no hay ataque de fase 1")
	boss.eye_open = 1.0
	player.global_position = boss.eye.global_position + Vector3(0, -3, 9)
	assert_true(boss.choose_attack(2) and boss.chosen_attack.id in [BossAttack.ORB, BossAttack.LASER] and boss.attacker == boss.eye, "en la fase 2 dispara el ojo")
	boss.free()


func test_the_hands_slam_wherever_the_player_dodges() -> void:
	var boss := _spawn()
	boss.rng.seed = 11
	var player := Node3D.new()
	boss.add_child(player)
	boss.target = player
	for away in [2.0, 6.0, 10.0]:
		player.global_position = boss.hand_rest(boss.hand_left).global_position + Vector3(0, 0, away)
		var slams := 0
		boss.chosen_attack = null
		for i in 20:
			boss.choose_attack(1)
			if boss.chosen_attack.id == BossAttack.SLAM:
				slams += 1
		assert_true(slams >= 4, "a %.0f m de la mano también golpea el piso (%d de 20)" % [away, slams])
	boss.free()


func test_overlay_shows_the_fight() -> void:
	var boss := _spawn()
	boss.start_fight()
	boss.target = null
	assert_true(boss.choose_attack(1))
	await (Engine.get_main_loop() as SceneTree).physics_frame
	await (Engine.get_main_loop() as SceneTree).physics_frame
	var values: Dictionary = DebugOverlay.get(&"_values")
	assert_eq(values.get("boss/phase"), 1)
	assert_eq(values.get("boss/hand_left"), "READY")
	assert_true(String(values.get("boss/attack", "-")) != "-", "muestra el ataque elegido")
	assert_eq(boss.phases.blackboard.get_var(&"hand_right"), "READY", "el blackboard tiene el estado de las manos")
	boss.free()


func test_boss_fits_its_room() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.get_node(^"GameState").reset()
	tree.change_scene_to_file("res://levels/templo.tscn")
	await tree.scene_changed
	var level := tree.current_scene
	var boss := level.get_node(^"Boss") as Boss
	var bounds := (level.get_node(^"Planta/Jefe") as Room).bounds()
	for mesh: MeshInstance3D in boss.find_children("*", "MeshInstance3D", true, false):
		if not mesh.is_visible_in_tree():
			continue
		var box := mesh.global_transform * mesh.get_aabb()
		assert_true(bounds.grow(0.01).encloses(Rect2(box.position.x, box.position.z, box.size.x, box.size.z)), "%s dentro de la sala" % mesh.get_path())
	var behind := Vector2(boss.global_position.x, boss.global_position.z - 2.5)
	assert_true(bounds.has_point(behind) and boss.arena.has_point(behind), "detrás del jefe también lo alcanzan los ataques")
	tree.root.get_node(^"GameState").reset()


func _wait_until(done: Callable, seconds: float) -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not done.call():
		if Time.get_ticks_msec() > until:
			return false
		await tree.process_frame
	return true


func test_arena_closes_intro_unskippable_the_first_time_and_bar() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.get_node(^"GameState").reset()
	tree.change_scene_to_file("res://levels/templo.tscn")
	await tree.scene_changed
	var level := tree.current_scene
	var player := tree.get_first_node_in_group(&"player") as Node3D
	var door := level.get_node(^"Planta/BossDoor") as Door
	var arena := level.get_node(^"BossArena") as BossArena
	var boss := level.get_node(^"Boss") as Boss
	var hud := level.get_node(^"HUD")
	door.open(false)
	player.global_position = Vector3(66, 0, 19)
	for i in 10:
		await tree.physics_frame
	player.global_position = Vector3(66, 0, 11.5)
	assert_true(await _wait_until(func() -> bool: return not door.is_open, 3.0), "al entrar se cierra la puerta")
	assert_true(await _wait_until(func() -> bool: return arena.in_intro, 2.0), "arranca la intro")
	assert_true(not boss.phases.is_active(), "durante la intro no pelea")
	await tree.create_timer(0.8, true).timeout
	var sounding := level.get_children().filter(func(n: Node) -> bool: return n is AudioStreamPlayer3D and n.playing and n.can_process())
	assert_true(not sounding.is_empty(), "el temblor de la intro suena durante la pausa del acercamiento")
	var skip := InputEventAction.new()
	skip.action = &"ui_accept"
	skip.pressed = true
	tree.root.push_input(skip)
	await tree.create_timer(0.5, true).timeout
	assert_true(arena.in_intro and not boss.phases.is_active(), "la primera vez la intro no se saltea")
	assert_true(await _wait_until(func() -> bool: return boss.phases.is_active(), 6.0), "después de la intro empieza la pelea")
	assert_true(not tree.paused, "el juego sigue")
	assert_true(hud.boss_bar.visible and is_equal_approx(hud.boss_health.value, 1.0), "aparece la barra llena")
	assert_eq(hud.get_node(^"%BossPhase").text, hud.tr("HUD_BOSS_PHASE").format({phase = 1}))
	boss.hand_left.stun(5.0)
	boss.hand_left.hurtbox.receive(_hit(3))
	await tree.create_timer(0.4).timeout
	assert_true(hud.boss_health.value < 1.0, "la barra baja al pegarle")
	boss.health.invulnerability_time = 0.0
	_knock_down(boss.hand_left)
	_knock_down(boss.hand_right)
	boss.health.damage(boss.health.max_health)
	assert_true(await _wait_until(func() -> bool: return not hud.boss_bar.visible, 12.0), "al ganar la barra se va")
	assert_true(await _wait_until(func() -> bool: return tree.root.get_node(^"GameState").get_flag(&"te_boss_defeated") == true, 5.0), "vencido")
	await tree.create_timer(0.6).timeout
	assert_true(not door.is_open, "la puerta queda cerrada: el portal es la única salida")
	tree.root.get_node(^"GameState").reset()


## La Guarida del templo, con la intro ya vista: el player al sur del jefe, sin pelea andando.
func _field(shield := &"") -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	var state := tree.root.get_node(^"GameState")
	state.reset()
	if shield != &"":
		state.give(Items.get_item(shield))
		state.equip(Items.get_item(shield))
	tree.change_scene_to_file("res://levels/templo.tscn")
	await tree.scene_changed
	var level := tree.current_scene
	(level.get_node(^"BossArena") as BossArena).started = true
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	player.global_position = Vector3(66, 0, 11)
	_single_slams(level.get_node(^"Boss") as Boss)
	for i in 10:
		await tree.physics_frame
	return [tree, player, level.get_node(^"Boss") as Boss]


func _attack(id: StringName) -> BossAttack:
	return load("res://data/boss/attack_%s.tres" % id)


func _press(tree: SceneTree, action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await tree.physics_frame
	var release := InputEventAction.new()
	release.action = action
	Input.parse_input_event(release)
	await tree.physics_frame


func test_slam_shadow_shrinks_then_stuns() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var boss := _spawn()
	var target := Node3D.new()
	boss.add_child(target)
	target.global_position = boss.global_position + Vector3(1, 0, 6)
	var hand := boss.hand_left
	hand.slam_stun_time = 0.4
	hand.perform(_attack(&"slam"), target, boss.arena)
	assert_true(hand.striking and hand.state == BossHand.State.BUSY, "golpeando")
	await tree.create_timer(0.8).timeout
	var early: float = hand.shadow.scale.x
	assert_true(hand.shadow.visible, "la sombra avisa dónde va a caer")
	await tree.create_timer(1.0).timeout
	assert_true(hand.shadow.scale.x < early, "la sombra se achica antes del impacto")
	assert_true(Vector2(hand.shadow.global_position.x, hand.shadow.global_position.z).distance_to(Vector2(target.global_position.x, target.global_position.z)) < 0.6, "la sombra sigue al player")
	assert_true(await _wait_until(func() -> bool: return hand.state == BossHand.State.STUNNED, 1.5), "tras el golpe al piso queda aturdida")
	assert_true(hand.global_position.y < 1.0, "apoyada en el piso")
	assert_true(not hand.striking and not boss.is_attack_running(), "el jefe ya puede usar la otra mano")
	assert_true(await _wait_until(func() -> bool: return hand.state == BossHand.State.READY, 2.0), "se repone")
	assert_true(hand.global_position.distance_to(hand.rest.global_position) < 0.05, "y vuelve a su lugar")
	boss.free()


func test_a_slam_chains_its_blows() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var boss := SCENE.instantiate() as Boss
	tree.root.add_child(boss)
	var target := Node3D.new()
	boss.add_child(target)
	target.global_position = boss.global_position + Vector3(1, 0, 6)
	var hand := boss.hand_left
	assert_true(hand.slam_count > 1, "golpea más de una vez por ataque")
	hand.slam_stun_time = 0.3
	var impacts := 0
	var was_visible := false
	hand.perform(_attack(&"slam"), target, boss.arena)
	var until := Time.get_ticks_msec() + 12000
	while hand.state != BossHand.State.STUNNED and Time.get_ticks_msec() < until:
		if hand.ring.visible and not was_visible:
			impacts += 1
			assert_true(hand.state == BossHand.State.BUSY, "entre golpes no queda aturdida")
		was_visible = hand.ring.visible
		await tree.process_frame
	assert_eq(hand.state, BossHand.State.STUNNED, "después de la tanda queda aturdida")
	assert_eq(impacts, hand.slam_count, "un impacto por golpe")
	boss.free()


func test_slam_hits_unless_you_leave_the_shadow() -> void:
	var setup: Array = await _field()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var boss: Boss = setup[2]
	var hand := boss.hand_left
	hand.slam_stun_time = 0.2
	var full := player.health.current
	hand.perform(_attack(&"slam"), player, boss.arena)
	assert_true(await _wait_until(func() -> bool: return hand.state == BossHand.State.STUNNED, 4.0))
	assert_true(player.health.current < full, "quieto bajo la sombra recibe el golpe")
	assert_true(await _wait_until(func() -> bool: return hand.state == BossHand.State.READY, 3.0))
	await tree.create_timer(1.0).timeout
	var before := player.health.current
	hand.perform(_attack(&"slam"), player, boss.arena)
	await tree.create_timer(hand.slam_rise_time + hand.slam_track_time + 0.05).timeout
	player.global_position += Vector3(3.5, 0, 0)
	assert_true(await _wait_until(func() -> bool: return hand.state == BossHand.State.STUNNED, 2.0))
	await tree.create_timer(0.2).timeout
	assert_eq(player.health.current, before, "salir de la sombra a tiempo lo esquiva (la onda no llega)")
	tree.root.get_node(^"GameState").reset()


func test_grab_holds_and_mashing_frees() -> void:
	var setup: Array = await _field()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var boss: Boss = setup[2]
	var hand := boss.hand_right
	hand.perform(_attack(&"grab"), player, boss.arena)
	assert_true(await _wait_until(player.is_grabbed, 3.0), "la garra lo atrapa")
	await tree.create_timer(0.5).timeout
	assert_true(player.global_position.distance_to(hand.grip_point.global_position) < 0.05, "lo lleva en la mano")
	for i in 8:
		await _press(tree, &"attack")
	assert_true(not player.is_grabbed(), "apretando botones se suelta")
	assert_eq(hand.state, BossHand.State.STUNNED, "y la mano queda mareada")
	assert_true(await _wait_until(func() -> bool: return hand.state == BossHand.State.READY, 3.0))
	player.health.invulnerability_time = 0.1
	var before := player.health.current
	hand.perform(_attack(&"grab"), player, boss.arena)
	assert_true(await _wait_until(player.is_grabbed, 3.0))
	assert_true(await _wait_until(func() -> bool: return not player.is_grabbed(), hand.grab_hold_time + 1.5), "si no se suelta, lo tira")
	assert_true(player.health.current <= before - 4, "daño mientras lo aprieta y al tirarlo")
	tree.root.get_node(^"GameState").reset()


func test_roll_slips_the_grab() -> void:
	var setup: Array = await _field()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var boss: Boss = setup[2]
	player.health.make_invulnerable(5.0)
	boss.hand_right.perform(_attack(&"grab"), player, boss.arena)
	await _wait_until(func() -> bool: return not boss.hand_right.striking, 3.0)
	assert_true(not player.is_grabbed(), "con i-frames (rodando) no lo agarra")
	tree.root.get_node(^"GameState").reset()


func _open_phase_two(boss: Boss) -> void:
	boss.start_fight()
	_knock_down(boss.hand_left)
	_knock_down(boss.hand_right)
	await (Engine.get_main_loop() as SceneTree).create_timer(1.3).timeout
	await _wait_until(func() -> bool: return boss.phase() != 2 or (boss.eye_open >= 1.0 and not boss.is_transforming()), 6.0)


func test_phase_two_opens_the_eye_with_a_tremor() -> void:
	var boss := _spawn()
	await _open_phase_two(boss)
	assert_eq(boss.phase(), 2)
	assert_eq(boss.eye_open, 1.0, "el ojo se abre")
	assert_true(absf(boss.body.position.y - Boss.BODY_HEIGHT_OPEN) <= Boss.BOB_HEIGHT + 0.01, "el cuerpo baja a mirarte (flotando)")
	assert_true(boss.get_node(^"%Solid").is_in_group(&"targetable"), "se lo puede fijar con Z")
	var arrow := Projectile.new()
	boss.eye_hurtbox.receive(_hit(1, 0.0, arrow))
	arrow.free()
	assert_true(boss.is_eye_stunned(), "aturdido")
	assert_true(not boss.choose_attack(2), "aturdido no ataca: la ventana es para pegarle")
	await (Engine.get_main_loop() as SceneTree).create_timer(0.5).timeout
	assert_true(absf(boss.body.position.y - Boss.BODY_HEIGHT_STUNNED) <= Boss.BOB_HEIGHT + 0.01, "cae a tiro de espada")
	var lowest := INF
	for i in 30:
		await (Engine.get_main_loop() as SceneTree).process_frame
		lowest = minf(lowest, _body_bottom(boss))
	assert_true(lowest >= boss.global_position.y, "apoyado, sin hundirse en el piso (%.2f)" % lowest)
	boss.free()


func _body_bottom(boss: Boss) -> float:
	var mesh := boss.body.get_node(^"Mesh") as MeshInstance3D
	var bottom := INF
	for vertex in mesh.mesh.get_faces():
		bottom = minf(bottom, (mesh.global_transform * vertex).y)
	return bottom


func test_arrow_flies_into_the_eye_and_the_sword_finishes() -> void:
	var setup: Array = await _field()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var boss: Boss = setup[2]
	await _open_phase_two(boss)
	boss.target = null
	var arrow: Projectile = (Items.get_item(&"bow").behavior as ProjectileBehavior).projectile_scene.instantiate()
	tree.current_scene.add_child(arrow)
	var info := _hit(2)
	arrow.launch(player.global_position + Vector3(0, 1.0, -0.6), Vector3.FORWARD * 20.0, info)
	assert_true(await _wait_until(boss.is_eye_stunned, 2.0), "una flecha a la altura del player llega al ojo y lo aturde")
	boss.health.invulnerability_time = 0.0
	var another := Projectile.new()
	var hits := 0
	while boss.health.current > 0 and hits < 40:
		if boss.is_transforming():
			assert_true(await _wait_until(func() -> bool: return not boss.is_transforming(), 5.0), "la transformación termina")
		if not boss.is_eye_stunned():
			boss.eye_hurtbox.receive(_hit(1, 0.0, another))
		boss.eye_hurtbox.receive(_hit(2))
		hits += 1
	another.free()
	assert_eq(boss.phases.get_active_state().name, &"Defeated", "flecha y espada ganan la fase")
	tree.root.get_node(^"GameState").reset()


func test_reflected_orb_stuns_the_eye() -> void:
	var setup: Array = await _field(&"shield_mirror")
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var boss: Boss = setup[2]
	await _open_phase_two(boss)
	for hand in [boss.hand_left, boss.hand_right]:
		hand.set_state(BossHand.State.DOWN)
	player.model.look_at(player.model.global_position + Vector3.BACK, Vector3.UP)
	player.health.make_invulnerable(30.0)
	hold_block(player, true)
	use_gamepad()
	boss.target = player
	boss._fire_orb()
	assert_true(await _wait_until(boss.is_eye_stunned, 4.0), "el orbe devuelto con el espejo aturde al ojo")
	assert_eq(boss.health.current, boss.health.max_health, "aturdir no le saca vida")
	tree.root.get_node(^"GameState").reset()


func test_win_take_the_container_then_the_portal_ends_the_demo() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	var saves: Node = tree.root.get_node(^"SaveManager")
	var stack: Node = tree.root.get_node(^"MenuStack")
	assert_eq(await saves.load_scenario("pre_boss"), OK)
	saves.current_slot = 8
	var level := tree.current_scene
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	var boss := level.get_node(^"Boss") as Boss
	var portal := level.get_node(^"BossExitPortal") as Portal
	assert_true(not portal.visible, "el portal de salida no está hasta vencerlo")
	(level.get_node(^"BossArena") as BossArena).started = true
	player.global_position = Vector3(66, 0, 11)
	player.health.make_invulnerable(999.0)
	for i in 10:
		await tree.physics_frame
	boss.start_fight()
	_knock_down(boss.hand_left)
	_knock_down(boss.hand_right)
	boss.health.invulnerability_time = 0.0
	boss.health.damage(boss.health.max_health)
	var max_before: int = state.max_health
	assert_true(await _wait_until(func() -> bool: return state.get_flag(&"te_boss_defeated") == true, 6.0), "flag te_boss_defeated")
	assert_true(not is_instance_valid(boss) or not boss.visible, "el jefe ya no está")
	assert_true(portal.visible, "aparece el portal de salida")
	var rewards := Spawns.root(level).find_children("*", "Pickup", false, false).filter(func(pickup: Pickup) -> bool: return pickup.item_get)
	assert_eq(rewards.size(), 1, "aparece el contenedor de corazón")
	var reward := rewards[0] as Pickup
	await tree.create_timer(0.5).timeout
	player.global_position = reward.global_position
	assert_true(await _wait_until(stack.is_open, 3.0), "item get del contenedor")
	assert_eq(state.max_health, max_before + 4, "suma un corazón")
	assert_eq(player.health.max_health, max_before + 4, "el player lo tiene en el momento")
	assert_true(player.health.is_full(), "con la vida llena")
	stack.pop()
	await tree.create_timer(1.0).timeout
	assert_true(not stack.is_open(), "tomar el contenedor no corta el juego")
	assert_true(not (level.get_node(^"Planta/BossDoor") as Door).is_open, "la puerta sigue cerrada")
	player.global_position = portal.global_position
	assert_true(await _wait_until(func() -> bool: return stack.top() is TextBox, 3.0), "el portal abre el diálogo de fin")
	assert_eq(tree.current_scene, level, "sin viajar")
	var box := stack.top() as TextBox
	assert_true(await _wait_until(func() -> bool: return box.responses.visible, 4.0), "con sus respuestas")
	assert_eq(box.responses.get_child_count(), 3, "seguir, revancha y menú")
	await tree.create_timer(box.input_guard + 0.05).timeout
	(box.responses.get_child(2) as Button).pressed.emit()
	await tree.scene_changed
	assert_eq(tree.current_scene.scene_file_path, "res://src/ui/title/title_screen.tscn", "vuelve al título")
	state.reset()
	assert_eq(await saves.load_game(8), OK)
	level = tree.current_scene
	await tree.process_frame
	assert_true(level.get_node_or_null(^"Boss") == null, "cargando después, el jefe no reaparece")
	assert_true((level.get_node(^"BossExitPortal") as Portal).visible, "y el portal sigue abierto")
	assert_true(not (level.get_node(^"Planta/BossDoor") as Door).is_open, "con la puerta cerrada")
	assert_eq(level.get_node(^"BossArena").find_children("*", "Pickup", false, false).size(), 0, "ni el contenedor")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saves.slot_path(8)))
	state.reset()


func test_keep_playing_finishes_the_trip_to_the_overworld() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	var saves: Node = tree.root.get_node(^"SaveManager")
	var stack: Node = tree.root.get_node(^"MenuStack")
	assert_eq(await saves.load_scenario("pre_boss"), OK)
	state.set_flag(&"te_boss_defeated", true)
	tree.reload_current_scene()
	await tree.scene_changed
	await tree.create_timer(0.2).timeout
	var portal := tree.current_scene.get_node(^"BossExitPortal") as Portal
	(tree.get_first_node_in_group(&"player") as Node3D).global_position = portal.global_position
	assert_true(await _wait_until(func() -> bool: return stack.top() is TextBox, 3.0), "el diálogo de fin")
	var box := stack.top() as TextBox
	assert_true(await _wait_until(func() -> bool: return box.responses.visible, 4.0))
	await tree.create_timer(box.input_guard + 0.05).timeout
	(box.responses.get_child(0) as Button).pressed.emit()
	await tree.scene_changed
	assert_eq(tree.current_scene.scene_file_path, "res://levels/overworld.tscn", "seguir jugando lleva al overworld")
	assert_true(state.get_flag(&"te_boss_defeated") == true, "con el progreso")
	assert_true(await _wait_until(func() -> bool: return not tree.root.get_node(^"SceneFlow").traveling, 3.0), "termina el viaje")
	state.reset()


func test_rematch_brings_the_boss_back_without_another_container() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	var saves: Node = tree.root.get_node(^"SaveManager")
	assert_eq(await saves.load_scenario("pre_boss"), OK)
	state.set_flag(&"te_boss_defeated", true)
	state.set_flag(&"te_heart_container", true)
	tree.reload_current_scene()
	await tree.scene_changed
	await tree.process_frame
	var arena := tree.current_scene.get_node(^"BossArena") as BossArena
	assert_true(tree.current_scene.get_node_or_null(^"Boss") == null, "vencido, el jefe no está")
	arena.start_rematch()
	await tree.scene_changed
	await tree.create_timer(0.2).timeout
	var level := tree.current_scene
	arena = level.get_node(^"BossArena") as BossArena
	var boss := level.get_node_or_null(^"Boss") as Boss
	var portal := level.get_node(^"BossExitPortal") as Portal
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	assert_true(boss != null, "en la revancha el jefe vuelve")
	assert_true(not portal.visible, "sin portal mientras pelea")
	assert_true((level.get_node(^"Planta/Jefe") as Room).contains(player.global_position), "el player aparece en la arena")
	assert_true(await _wait_until(func() -> bool: return boss.phases.is_active() or arena.in_intro, 4.0), "arranca la pelea")
	await tree.create_timer(0.8, true).timeout
	var skipped_at := Time.get_ticks_msec()
	_skip_intro(tree)
	assert_true(await _wait_until(func() -> bool: return boss.phases.is_active(), 6.0), "pelea")
	assert_true(Time.get_ticks_msec() - skipped_at < 1200, "en la revancha la intro se saltea")
	player.health.make_invulnerable(999.0)
	_knock_down(boss.hand_left)
	_knock_down(boss.hand_right)
	boss.health.invulnerability_time = 0.0
	boss.health.damage(boss.health.max_health)
	assert_true(await _wait_until(func() -> bool: return portal.visible, 8.0), "al ganar vuelve el portal")
	assert_true(not state.boss_rematch, "termina la revancha")
	assert_eq(arena.find_children("*", "Pickup", false, false).size(), 0, "sin otro contenedor")
	state.reset()


func _skip_intro(tree: SceneTree) -> void:
	var skip := InputEventAction.new()
	skip.action = &"ui_accept"
	skip.pressed = true
	tree.root.push_input(skip)


func test_phase_three_below_a_third() -> void:
	var boss := _spawn()
	await _open_phase_two(boss)
	boss.health.invulnerability_time = 0.0
	var phases_seen: Array[int] = []
	boss.phase_changed.connect(func(value: int) -> void: phases_seen.append(value))
	boss.health.damage(boss.health.max_health - 9)
	assert_eq(boss.phase(), 2, "con más de un tercio sigue la fase 2")
	boss.health.damage(1)
	assert_eq(boss.phase(), 3, "a un tercio de vida, fase 3")
	assert_eq(phases_seen, [3] as Array[int])
	boss.target = null
	assert_true(boss.is_transforming() and not boss.choose_attack(3), "al entrar a la fase 3 se transforma y no ataca")
	var hp := boss.health.current
	boss.eye_hurtbox.receive(_hit(5))
	assert_eq(boss.health.current, hp, "transformándose no recibe daño")
	assert_true(await _wait_until(func() -> bool: return not boss.is_transforming(), 5.0), "la transformación termina")
	assert_eq((boss.body.get_node(^"Mesh") as MeshInstance3D).mesh.resource_path.get_file(), "jefe_corrupto_cuerpo.res", "queda el ojo corrupto")
	var seen := {}
	for i in 20:
		if boss.choose_attack(3):
			seen[boss.chosen_attack.id] = true
	assert_true(seen.has(&"mark"), "el ojo marca el piso")
	assert_true(not seen.has(&"grab"), "el agarre es solo de la fase 1")
	boss.health.damage(99)
	assert_eq(boss.phases.get_active_state().name, &"Defeated", "desde la fase 3 también se lo vence")
	boss.free()


func test_marks_keep_the_eye_busy_until_they_blast() -> void:
	var boss := _spawn()
	for hand in [boss.hand_left, boss.hand_right]:
		hand.set_state(BossHand.State.DOWN)
	var target := Node3D.new()
	boss.add_child(target)
	boss.target = target
	var tree := Engine.get_main_loop() as SceneTree
	boss._mark_floor()
	await tree.create_timer(boss.mark_telegraph - 0.3).timeout
	assert_true(boss.is_attack_running(), "mientras se cargan las marcas no encadena otro ataque")
	await tree.create_timer(0.5).timeout
	assert_true(not boss.is_attack_running(), "después del estallido sí")
	boss.free()


## Con las dos manos fuera de juego en las fases 2 y 3, el ojo alterna orbe y rayo; con manos, nunca el rayo.
func test_with_both_hands_out_the_eye_alternates_orb_and_laser() -> void:
	var boss := _spawn()
	var tree := Engine.get_main_loop() as SceneTree
	await _frames(2)
	var target := Node3D.new()
	boss.add_child(target)
	target.global_position = boss.global_position + Vector3(0, -boss.global_position.y, 6)
	boss.target = target
	boss.eye_open = 1.0
	for i in 20:
		if boss.choose_attack(2):
			assert_true(boss.chosen_attack.id != BossAttack.LASER, "con las manos, sin rayo")
	boss.hand_left.stun(5.0)
	boss.hand_right.set_state(BossHand.State.DOWN)
	assert_true(boss.hands_out(), "una aturdida y otra caída: fuera de juego")
	var seen: Array[StringName] = []
	for i in 6:
		assert_true(boss.choose_attack(3), "elige")
		assert_true(boss.attacker == boss.eye and boss.chosen_attack.id in [BossAttack.ORB, BossAttack.LASER], "solo el ojo, orbe o rayo")
		seen.append(boss.chosen_attack.id)
		boss._last_eye_attack = boss.chosen_attack.id
	for i in range(1, seen.size()):
		assert_true(seen[i] != seen[i - 1], "alterna: %s" % [seen])
	boss._sweep_laser()
	assert_true(boss.get_node(^"%LaserPath").visible and not boss.get_node(^"%LaserBeam").visible, "primero marca la línea")
	await tree.create_timer(boss.laser_charge_time + 0.2).timeout
	assert_true(boss.get_node(^"%LaserBeam").visible and boss.get_node(^"%LaserSpot").monitoring, "después barre con el rayo")
	assert_true(boss.is_attack_running(), "mientras barre no encadena otro ataque")
	await tree.create_timer(boss.laser_sweep_time).timeout
	assert_true(not boss.is_attack_running() and not boss.get_node(^"%LaserBeam").visible, "termina y se apaga")
	boss._sweep_laser()
	boss._stun_eye()
	assert_true(not boss.is_attack_running() and not boss.get_node(^"%LaserPath").visible, "aturdido, el rayo se corta")
	await tree.create_timer(boss.laser_charge_time + 0.2).timeout
	assert_true(not boss.get_node(^"%LaserBeam").visible, "y no barre después")
	boss.free()


func test_marks_always_leave_a_way_out() -> void:
	var boss := _spawn()
	var target := Node3D.new()
	boss.add_child(target)
	boss.target = target
	var corners := [boss.arena.position, boss.arena.end, Vector2(boss.arena.position.x, boss.arena.end.y), boss.arena.get_center()]
	var counts := {}
	for seed in 40:
		boss.rng.seed = seed
		var spot: Vector2 = corners[seed % corners.size()]
		target.global_position = Vector3(spot.x, 0.0, spot.y)
		var marks: Array[Vector3] = boss._mark_points()
		counts[marks.size()] = counts.get(marks.size(), 0) + 1
		var safe := false
		for step in 24:
			var angle := TAU * step / 24.0
			var point: Vector3 = target.global_position + Vector3(cos(angle), 0.0, sin(angle)) * 2.4
			if not boss.arena.grow(0.5).has_point(Vector2(point.x, point.z)):
				continue
			if marks.all(func(mark: Vector3) -> bool: return mark.distance_to(point) > boss.mark_radius + 0.3):
				safe = true
				break
		assert_true(safe, "a 2,4 m del player (menos de medio segundo corriendo) hay piso sin marcar (semilla %d)" % seed)
	assert_true(counts.get(boss.mark_count, 0) >= 36, "casi siempre marca las tres (%s)" % counts)
	boss.free()


func test_marks_blast_whoever_stays_even_blocking() -> void:
	var setup: Array = await _field(&"shield_mirror")
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var boss: Boss = setup[2]
	await _open_phase_two(boss)
	boss.health.invulnerability_time = 0.0
	boss.health.damage(boss.health.max_health - 8)
	assert_eq(boss.phase(), 3)
	await _wait_until(func() -> bool: return not boss.is_transforming() and not tree.paused, 8.0)
	boss.phases.set_active(false)
	for hand in [boss.hand_left, boss.hand_right]:
		hand.set_state(BossHand.State.DOWN)
	boss.target = player
	player.health.invulnerability_time = 0.0
	player.health.reset(40)
	var full := player.health.current
	boss._mark_floor()
	var marks := boss.get_children().filter(func(node: Node) -> bool: return node is Decal and node.visible)
	assert_eq(marks.size(), boss.mark_count, "marca el piso")
	assert_true(marks.any(func(mark: Decal) -> bool: return Vector2(mark.global_position.x, mark.global_position.z).distance_to(Vector2(player.global_position.x, player.global_position.z)) < 0.1), "una marca bajo el player")
	hold_block(player, true)
	await tree.create_timer(boss.mark_telegraph + 0.2).timeout
	assert_true(player.health.current < full, "quedarse en la marca lastima, aunque bloquee")
	hold_block(player, false)
	await tree.create_timer(1.0).timeout
	var before := player.health.current
	boss._mark_floor()
	var points: Array = boss.get_children().filter(func(node: Node) -> bool: return node is Decal and node.visible).map(func(mark: Decal) -> Vector3: return Vector3(mark.global_position.x, 0, mark.global_position.z))
	var escape := player.global_position
	for step in 24:
		var candidate := player.global_position + Vector3(cos(TAU * step / 24.0), 0, sin(TAU * step / 24.0)) * 2.4
		if points.all(func(p: Vector3) -> bool: return p.distance_to(Vector3(candidate.x, 0, candidate.z)) > boss.mark_radius + 0.3) and boss.arena.has_point(Vector2(candidate.x, candidate.z)):
			escape = candidate
			break
	player.global_position = escape
	await tree.create_timer(boss.mark_telegraph + 0.2).timeout
	assert_eq(player.health.current, before, "fuera de las marcas no pasa nada")
	tree.root.get_node(^"GameState").reset()


func test_the_bar_shows_the_eye_in_phase_three() -> void:
	var boss := _spawn()
	await _open_phase_two(boss)
	boss.health.invulnerability_time = 0.0
	boss.health.damage(boss.health.max_health - 6)
	assert_eq(boss.phase(), 3)
	assert_eq(boss.bar_fraction(), 6.0 / boss.health.max_health, "en la fase 3 la barra sigue siendo la vida del ojo")
	boss.free()


func test_a_collapsing_hand_stops_its_windup() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var boss := _spawn()
	var target := Node3D.new()
	boss.add_child(target)
	target.global_position = boss.global_position + Vector3(1, 0, 6)
	var hand := boss.hand_left
	hand.perform(_attack(&"sweep"), target, boss.arena)
	assert_true(await _wait_until(func() -> bool: return hand._attack_tween != null and hand._attack_tween.is_running(), 2.0), "carga el barrido")
	hand.collapse()
	assert_true(not hand._attack_tween.is_valid(), "al caer, el aviso del ataque se corta")
	await tree.create_timer(0.5).timeout
	var resting := hand.global_position
	await tree.create_timer(0.5).timeout
	assert_true(hand.global_position.is_equal_approx(resting), "y queda quieta en el piso")
	boss.free()


func test_stunning_the_eye_cuts_the_orb_charge() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var boss := _spawn()
	await _open_phase_two(boss)
	var target := Node3D.new()
	boss.add_child(target)
	target.global_position = boss.global_position + Vector3(0, 0, 8)
	boss.target = target
	boss.phases.set_active(false)
	var orbs := func() -> int: return tree.current_scene.find_children("*", "Projectile", true, false).size() if tree.current_scene else 0
	var before: int = orbs.call()
	boss._fire_orb()
	await tree.create_timer(boss.orb_charge_time * 0.4).timeout
	boss._stun_eye()
	assert_true(not boss.is_attack_running(), "aturdido, el ojo deja de cargar")
	await tree.create_timer(boss.orb_charge_time).timeout
	assert_eq(boss._squint, 0.0, "la carga no le vuelve a entrecerrar el ojo")
	assert_true(not boss.get_node(^"%Charge").visible)
	assert_eq(orbs.call(), before, "ni dispara")
	boss.free()


func test_attack_ids_match_the_code() -> void:
	for file in DirAccess.get_files_at("res://data/boss"):
		if file.begins_with("attack_") and file.ends_with(".tres"):
			var attack: BossAttack = load("res://data/boss/" + file)
			assert_true(attack.id in BossAttack.IDS, "%s: id %s es uno de BossAttack.IDS" % [file, attack.id])


## 11.85: un id que el ojo no conoce no dispara un orbe por defecto.
func test_unknown_eye_attack_does_nothing() -> void:
	var boss := _spawn()
	var tree := Engine.get_main_loop() as SceneTree
	await _frames(2)
	var target := Node3D.new()
	tree.root.add_child(target)
	target.global_position = boss.global_position + Vector3(0, 0, 6)
	var unknown := BossAttack.new()
	unknown.id = &"nope"
	unknown.user = BossAttack.User.EYE
	boss.chosen_attack = unknown
	boss.attacker = boss.eye
	boss.target = target
	var before := Spawns.root(boss).find_children("*", "Projectile", false, false).size()
	boss.perform_chosen()
	await _frames(2)
	assert_eq(Spawns.root(boss).find_children("*", "Projectile", false, false).size(), before, "sin orbe")
	target.free()
	boss.free()


func test_the_orb_goes_through_the_boss_own_body() -> void:
	var boss := _spawn()
	var info := DamageInfo.make(1, 1.0, boss)
	var orb := Projectile.fire(Boss.ORB, boss, boss.orb_muzzle.global_position, Vector3.BACK, info)
	orb._on_body_entered(boss.get_node(^"%Solid"))
	assert_eq(orb.is_queued_for_deletion(), false, "con el player detrás del ojo, el orbe no choca contra el jefe")
	var wall := StaticBody3D.new()
	boss.get_parent().add_child(wall)
	orb._on_body_entered(wall)
	assert_eq(orb.is_queued_for_deletion(), true, "contra una pared sí")
	wall.free()
	boss.free()
