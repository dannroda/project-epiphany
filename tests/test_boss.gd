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
	hand.hurtbox.receive(_hit(1, 1.0))
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
	assert_true(boss.hand_left.is_available() and boss.hand_left.health.is_full(), "las manos se regeneran")
	await (Engine.get_main_loop() as SceneTree).create_timer(1.0).timeout
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
		var box := mesh.global_transform * mesh.get_aabb()
		assert_true(bounds.grow(0.01).encloses(Rect2(box.position.x, box.position.z, box.size.x, box.size.z)), "%s dentro de la sala" % mesh.get_path())
	tree.root.get_node(^"GameState").reset()
