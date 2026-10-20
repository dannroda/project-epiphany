extends "res://tests/test_case.gd"
## El jefe se siente vivo y pesado (11.46).

const SCENE := preload("res://src/entities/boss/boss.tscn")


func _spawn() -> Boss:
	var tree := Engine.get_main_loop() as SceneTree
	if tree.current_scene == null:
		var level := Node3D.new()
		tree.root.add_child(level)
		tree.current_scene = level
	var boss := SCENE.instantiate() as Boss
	tree.current_scene.add_child(boss)
	return boss


func _wait(seconds: float) -> void:
	await (Engine.get_main_loop() as SceneTree).create_timer(seconds).timeout


func _knock_down(hand: BossHand) -> void:
	var info := DamageInfo.new()
	info.amount = hand.health.max_health
	info.team = EntityConfig.Team.PLAYER
	hand.health.invulnerability_time = 0.0
	hand.stun(1.0)
	hand.hurtbox.receive(info)


func test_body_floats_and_hands_follow() -> void:
	var boss := _spawn()
	var heights: Array[float] = []
	for i in 6:
		await _wait(0.1)
		heights.append(boss.body.position.y)
	assert_true(heights.max() - heights.min() > 0.05, "el cuerpo sube y baja")
	assert_true(boss.hand_left.global_position.distance_to(boss.hand_rest(boss.hand_left).global_position) < 0.01, "la mano en reposo flota con él")
	boss.free()


func test_iris_glows_while_charging_the_orb() -> void:
	var boss := _spawn()
	boss.eye_open = 1.0
	boss.target = Node3D.new()
	boss.add_child(boss.target)
	boss.target.position = Vector3(0, 0, 8)
	var resting := boss.eye_glow()
	boss._fire_orb()
	await _wait(boss.orb_charge_time * 0.85)
	assert_true(boss.eye_glow() > resting * 2.0, "el iris se enciende (%.1f)" % boss.eye_glow())
	assert_true(boss.get_node(^"%UpperLid").rotation.x > deg_to_rad(-Boss.LID_OPEN_ANGLE) + 0.2, "entrecierra los párpados al apuntar")
	await _wait(0.6)
	assert_true(is_equal_approx(boss.eye_glow(), resting), "y vuelve")
	boss.free()


func test_pupil_dilates_charging_snaps_to_a_slit_and_dazes() -> void:
	var boss := _spawn()
	boss.eye_open = 1.0
	boss.target = Node3D.new()
	boss.add_child(boss.target)
	boss.target.position = Vector3(0, 0, 8)
	var mesh: MeshInstance3D = boss.get_node(^"Body/Eye/Mesh")
	var slit := mesh.find_blend_shape_by_name(&"rendija")
	var wide := mesh.find_blend_shape_by_name(&"dilatada")
	assert_true(slit >= 0 and wide >= 0, "el ojo trae las dos formas de pupila")
	boss._fire_orb()
	await _wait(boss.orb_charge_time * 0.9)
	assert_true(boss.pupil > 0.4 and mesh.get_blend_shape_value(wide) > 0.4, "se dilata mientras carga (%.2f)" % boss.pupil)
	await _wait(boss.orb_charge_time * 0.1 + 0.1)
	assert_true(boss.pupil < -0.5 and mesh.get_blend_shape_value(slit) > 0.5, "al disparar se cierra en rendija (%.2f)" % boss.pupil)
	await _wait(1.4)
	assert_true(absf(boss.pupil) < 0.15, "y vuelve a la normal (%.2f)" % boss.pupil)
	boss._stun_eye()
	await _wait(0.6)
	assert_true(boss.pupil > 0.6, "aturdido queda dilatada (%.2f)" % boss.pupil)
	boss.free()


func test_slam_squashes_and_leaves_a_crack() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var boss := _spawn()
	var target := Node3D.new()
	boss.add_child(target)
	target.global_position = boss.global_position + Vector3(1, 0, 6)
	var hand := boss.hand_left
	hand.slam_stun_time = 1.0
	hand.slam_count = 1
	var decals := func() -> int: return tree.current_scene.find_children("*", "Decal", true, false).filter(func(d: Decal) -> bool: return not boss.is_ancestor_of(d)).size()
	var before: int = decals.call()
	hand.perform(load("res://data/boss/attack_slam.tres"), target, boss.arena)
	var squashed := false
	var until := Time.get_ticks_msec() + 4000
	while hand.state != BossHand.State.STUNNED and Time.get_ticks_msec() < until:
		await tree.process_frame
		squashed = squashed or hand.mesh.scale.y < 0.9
	await tree.process_frame
	squashed = squashed or hand.mesh.scale.y < 0.9
	assert_true(squashed, "se aplasta al pegar")
	assert_eq(decals.call(), before + 1, "queda una grieta en el piso")
	assert_eq(Engine.time_scale, 1.0, "el hit-stop no deja el juego lento")
	await _wait(0.3)
	assert_true(absf(hand.rotation.z) > 0.01 or absf(hand.rotation.x) > 0.01, "aturdida se tambalea")
	boss.free()


func test_death_turns_off_the_neon_and_slows_time_briefly() -> void:
	var boss := _spawn()
	boss.start_fight()
	_knock_down(boss.hand_left)
	_knock_down(boss.hand_right)
	await _wait(1.3)
	boss.health.invulnerability_time = 0.0
	boss.health.damage(boss.health.max_health)
	await (Engine.get_main_loop() as SceneTree).process_frame
	assert_true(Engine.time_scale < 1.0, "cámara lenta en el último golpe")
	await (Engine.get_main_loop() as SceneTree).create_timer(Boss.SLOW_MOTION_TIME + 0.2, true, false, true).timeout
	assert_eq(Engine.time_scale, 1.0, "y vuelve a velocidad normal")
	await _wait(1.6)
	assert_true(boss.eye_glow() < 0.1, "el neón se apaga")
	boss.free()
	assert_eq(Engine.time_scale, 1.0)


func test_the_boss_has_its_own_voice() -> void:
	for sound in [&"boss_lid", &"boss_roar", &"boss_slam", &"boss_eye_hit"]:
		assert_true(not Feel.streams_of(sound).is_empty(), "%s tiene sus muestras (11.50)" % sound)
	var boss := _spawn()
	assert_true(boss.get_node(^"%Hum").playing, "zumba de fondo")
	boss.eye_open = 1.0
	boss.target = Node3D.new()
	boss.add_child(boss.target)
	var charge := boss.get_node(^"Body/Eye/OrbMuzzle/ChargeSound") as AudioStreamPlayer3D
	boss._fire_orb()
	await _wait(0.2)
	assert_true(charge.playing, "suena la carga del orbe")
	boss._stun_eye()
	await _wait(0.1)
	assert_true(not charge.playing, "aturdido, la carga se corta")
	boss.free()
