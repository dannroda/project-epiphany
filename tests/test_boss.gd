extends "res://tests/test_case.gd"
## El jefe (M9): piezas sueltas que mueve el código.

const SCENE := preload("res://src/entities/boss/boss.tscn")


func _spawn() -> Boss:
	var tree := Engine.get_main_loop() as SceneTree
	var boss := SCENE.instantiate() as Boss
	tree.root.add_child(boss)
	return boss


func test_pieces_and_sockets() -> void:
	var boss := _spawn()
	for path in ["Body/Mesh", "%Eye", "%OrbMuzzle", "%UpperLid", "%LowerLid", "%HandAnchorLeft", "%HandAnchorRight", "%HandRestLeft", "%HandRestRight"]:
		assert_true(boss.get_node_or_null(path) != null, "tiene %s" % path)
	assert_true(boss.orb_muzzle.get_parent() == boss.eye, "los orbes salen del ojo y giran con él")
	assert_true(boss.hand_left.get_parent() == boss and boss.hand_right.get_parent() == boss, "las manos flotan sueltas")
	assert_true(boss.hand_rest(boss.hand_left).global_position.distance_to(boss.hand_left.global_position) < 0.01, "la mano izquierda arranca en su reposo")
	assert_true(boss.hand_left.global_position.x > 0.0, "la izquierda del jefe es +X (mira a la cámara)")
	boss.free()


func test_hands_show_one_pose() -> void:
	var boss := _spawn()
	for pose in [BossHand.Pose.OPEN, BossHand.Pose.FIST, BossHand.Pose.CLAW]:
		boss.hand_right.pose = pose
		var shown := [^"Open", ^"Fist", ^"Claw"].filter(func(mesh: NodePath) -> bool: return boss.hand_right.get_node(mesh).visible)
		assert_eq(shown.size(), 1, "una sola malla por pose")
	assert_eq(boss.hand_right.get_node(^"Claw").visible, true)
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
	assert_true(boss.choose_attack(2) and boss.chosen_attack.id == &"orb" and boss.attacker == boss.eye, "en la fase 2 dispara el ojo")
	boss.free()


func test_overlay_shows_the_fight() -> void:
	var boss := _spawn()
	boss.start_fight()
	boss.choose_attack(1)
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
	tree.change_scene_to_file("res://levels/temple.tscn")
	await tree.scene_changed
	var level := tree.current_scene
	var boss := level.get_node(^"Boss") as Boss
	var bounds := (level.get_node(^"Jefe") as Room).bounds()
	for mesh: MeshInstance3D in boss.find_children("*", "MeshInstance3D", true, false):
		if not mesh.is_visible_in_tree():
			continue
		var box := mesh.global_transform * mesh.get_aabb()
		assert_true(bounds.grow(0.01).encloses(Rect2(box.position.x, box.position.z, box.size.x, box.size.z)), "%s dentro de la sala" % mesh.get_path())
	tree.root.get_node(^"GameState").reset()


func _wait_until(done: Callable, seconds: float) -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not done.call():
		if Time.get_ticks_msec() > until:
			return false
		await tree.process_frame
	return true


func test_arena_closes_skippable_intro_and_bar() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.get_node(^"GameState").reset()
	tree.change_scene_to_file("res://levels/temple.tscn")
	await tree.scene_changed
	var level := tree.current_scene
	var player := tree.get_first_node_in_group(&"player") as Node3D
	var door := level.get_node(^"BossDoor") as Door
	var arena := level.get_node(^"BossArena") as BossArena
	var boss := level.get_node(^"Boss") as Boss
	var hud := level.get_node(^"HUD")
	door.open(false)
	player.global_position = Vector3(24, 0, 27)
	for i in 10:
		await tree.physics_frame
	player.global_position = Vector3(24, 0, 21.5)
	assert_true(await _wait_until(func() -> bool: return not door.is_open, 3.0), "al entrar se cierra la puerta")
	assert_true(await _wait_until(func() -> bool: return arena.in_intro, 2.0), "arranca la intro")
	assert_true(not boss.phases.is_active(), "durante la intro no pelea")
	await tree.create_timer(0.8, true).timeout
	var skip := InputEventAction.new()
	skip.action = &"ui_accept"
	skip.pressed = true
	var skipped_at := Time.get_ticks_msec()
	tree.root.push_input(skip)
	assert_true(await _wait_until(func() -> bool: return boss.phases.is_active(), 3.0), "después de la intro empieza la pelea")
	assert_true(Time.get_ticks_msec() - skipped_at < 500, "la intro se salta")
	assert_true(not tree.paused, "el juego sigue")
	assert_true(hud.boss_bar.visible and is_equal_approx(hud.boss_health.value, 1.0), "aparece la barra llena")
	assert_eq(hud.get_node(^"%BossPhase").text, "Fase 1")
	boss.hand_left.stun(5.0)
	boss.hand_left.hurtbox.receive(_hit(3))
	await tree.create_timer(0.4).timeout
	assert_true(hud.boss_health.value < 1.0, "la barra baja al pegarle")
	boss.health.invulnerability_time = 0.0
	_knock_down(boss.hand_left)
	_knock_down(boss.hand_right)
	boss.health.damage(boss.health.max_health)
	await tree.create_timer(1.6).timeout
	assert_true(not hud.boss_bar.visible, "al ganar la barra se va")
	assert_true(await _wait_until(func() -> bool: return door.is_open, 5.0), "y se abre la puerta")
	tree.root.get_node(^"GameState").reset()


## La Guarida del templo, con la intro ya vista: el player al sur del jefe, sin pelea andando.
func _field(shield := &"") -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	var state := tree.root.get_node(^"GameState")
	state.reset()
	if shield != &"":
		state.give(Items.get_item(shield))
		state.equip(Items.get_item(shield))
	tree.change_scene_to_file("res://levels/temple.tscn")
	await tree.scene_changed
	var level := tree.current_scene
	(level.get_node(^"BossArena") as BossArena).started = true
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	player.global_position = Vector3(24, 0, 21)
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
	assert_true(player.global_position.distance_to(hand.grip.global_position) < 0.05, "lo lleva en la mano")
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


func test_phase_two_opens_the_eye_with_a_tremor() -> void:
	var boss := _spawn()
	await _open_phase_two(boss)
	assert_eq(boss.phase(), 2)
	assert_eq(boss.eye_open, 1.0, "el ojo se abre")
	assert_true(is_equal_approx(boss.body.position.y, Boss.BODY_HEIGHT_OPEN), "el cuerpo baja a mirarte")
	assert_true(boss.get_node(^"%Solid").is_in_group(&"targetable"), "se lo puede fijar con Z")
	var arrow := Projectile.new()
	boss.eye_hurtbox.receive(_hit(1, 0.0, arrow))
	arrow.free()
	assert_true(boss.is_eye_stunned(), "aturdido")
	assert_true(not boss.choose_attack(2), "aturdido no ataca: la ventana es para pegarle")
	await (Engine.get_main_loop() as SceneTree).create_timer(0.5).timeout
	assert_true(is_equal_approx(boss.body.position.y, Boss.BODY_HEIGHT_STUNNED), "cae a tiro de espada")
	boss.free()


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
	player.movement_state.blackboard.set_var("is_blocking", true)
	use_gamepad()
	player.set_guard(true)
	boss.target = player
	boss._fire_orb()
	assert_true(await _wait_until(boss.is_eye_stunned, 4.0), "el orbe devuelto con el espejo aturde al ojo")
	assert_eq(boss.health.current, boss.health.max_health, "aturdir no le saca vida")
	tree.root.get_node(^"GameState").reset()


func test_win_take_the_container_and_roll_credits() -> void:
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
	player.global_position = Vector3(24, 0, 21)
	player.health.make_invulnerable(999.0)
	for i in 10:
		await tree.physics_frame
	boss.start_fight()
	_knock_down(boss.hand_left)
	_knock_down(boss.hand_right)
	boss.health.invulnerability_time = 0.0
	boss.health.damage(boss.health.max_health)
	var max_before: int = state.max_health
	assert_true(await _wait_until(func() -> bool: return state.get_flag(&"d1_boss_defeated") == true, 6.0), "flag d1_boss_defeated")
	assert_true(not is_instance_valid(boss) or not boss.visible, "el jefe ya no está")
	assert_true(portal.visible, "aparece el portal de salida")
	var rewards := level.get_node(^"BossArena").find_children("*", "Pickup", false, false)
	assert_eq(rewards.size(), 1, "aparece el contenedor de corazón")
	var reward := rewards[0] as Pickup
	await tree.create_timer(0.5).timeout
	player.global_position = reward.global_position
	assert_true(await _wait_until(stack.is_open, 3.0), "item get del contenedor")
	assert_eq(state.max_health, max_before + 4, "suma un corazón")
	assert_eq(player.health.max_health, max_before + 4, "el player lo tiene en el momento")
	assert_true(player.health.is_full(), "con la vida llena")
	stack.pop()
	assert_true(await _wait_until(func() -> bool: return stack.top() is Ending, 3.0), "pantalla de fin")
	await tree.process_frame
	(stack.top().get_node(^"%ToTitle") as Button).pressed.emit()
	await tree.scene_changed
	assert_eq(tree.current_scene.scene_file_path, "res://src/ui/title/title_screen.tscn", "vuelve al título")
	state.reset()
	assert_eq(await saves.load_game(8), OK)
	level = tree.current_scene
	await tree.process_frame
	assert_true(level.get_node_or_null(^"Boss") == null, "cargando después, el jefe no reaparece")
	assert_true((level.get_node(^"BossExitPortal") as Portal).visible, "y el portal sigue abierto")
	assert_eq(level.get_node(^"BossArena").find_children("*", "Pickup", false, false).size(), 0, "ni el contenedor")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saves.slot_path(8)))
	state.reset()
