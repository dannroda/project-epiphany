extends "res://tests/test_case.gd"
## La Queñoa Vigía (D1, 11.113): tronco, copa y raíces; escaleras, caídas al piso de abajo y el bloque de la rama.

const LEVEL := "res://levels/quenoa.tscn"
const MapData := preload("res://src/ui/menus/map_data.gd")

var tree: SceneTree
var level: Node
var player: PlayerCharacter
var camera: TopDownCamera


func _start() -> void:
	tree = Engine.get_main_loop() as SceneTree
	tree.root.get_node(^"GameState").reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	await tree.create_timer(0.3).timeout
	level = tree.current_scene
	player = tree.get_first_node_in_group(&"player") as PlayerCharacter
	player.health.invulnerability_time = 0.0
	camera = level.get_node(^"TopDownCamera") as TopDownCamera
	for enemy in tree.get_nodes_in_group(&"enemies"):
		enemy.free()


func _room(path: String) -> Room:
	return level.get_node(path) as Room


## Un punto de la sala en sus propias coordenadas: x y z desde su centro, y desde su piso.
func _in(path: String, local: Vector3) -> Vector3:
	var room := _room(path)
	return Vector3(room.global_position.x, (room.get_parent() as Node3D).global_position.y, room.global_position.z) + local


func _drop(at: Vector3) -> void:
	player.global_position = at
	player.velocity = Vector3.ZERO
	var until := Time.get_ticks_msec() + 4000
	var airborne := false
	while Time.get_ticks_msec() < until and not (airborne and player.is_on_floor() and camera.room and camera.room.contains(player.global_position)):
		await tree.physics_frame
		airborne = airborne or not player.is_on_floor()
	await tree.create_timer(0.2).timeout


func test_starts_in_the_entrance_with_three_floors() -> void:
	await _start()
	assert_eq(camera.room, _room("PisoTronco/Entrada"), "arranca en la entrada")
	assert_true(camera.offset.is_equal_approx(Vector3(0, 30.814466, 14.369021)), "la cámara de la escena (la de LA), no la de por defecto")
	assert_eq(MapData.rooms_on(tree, 0).size(), 4, "cuatro salas en el tronco")
	assert_eq(MapData.rooms_on(tree, 1).size(), 4, "cuatro en la copa")
	assert_eq(MapData.rooms_on(tree, -1).size(), 3, "tres en las raíces")
	tree.root.get_node(^"GameState").reset()


func test_stairs_go_up_to_the_canopy_and_back() -> void:
	await _start()
	player.global_position = _in("PisoTronco/Escalera", Vector3(0, 0, -7.4))
	await tree.create_timer(1.2).timeout
	assert_eq(camera.room, _room("PisoCopa/Copa"), "la escalera sube a la copa")
	assert_true(absf(player.global_position.y - 8.0) < 0.5, "arriba (y %.1f)" % player.global_position.y)
	player.global_position = _in("PisoCopa/Copa", Vector3(0, 0, -7.4))
	await tree.create_timer(1.2).timeout
	assert_eq(camera.room, _room("PisoTronco/Escalera"), "y baja al hueco de la escalera")
	tree.root.get_node(^"GameState").reset()


func test_roots_stairs_sit_behind_the_trunk_gate() -> void:
	await _start()
	var gate := level.get_node(^"PisoTronco/TroncoGate") as Gate
	assert_true(not gate.is_open, "la reja del tronco arranca cerrada")
	tree.root.get_node(^"GameState").set_flag(&"qv_trunk_eye", true)
	await tree.create_timer(1.0).timeout
	assert_true(gate.is_open, "el ojo la abre")
	player.global_position = _in("PisoTronco/Tronco", Vector3(-11.4, 0, -4))
	await tree.create_timer(1.2).timeout
	assert_eq(camera.room, _room("PisoRaices/Raices"), "la bajada lleva a las raíces")
	player.global_position = _in("PisoRaices/Raices", Vector3(-11.4, 0, 4))
	await tree.create_timer(1.2).timeout
	assert_eq(camera.room, _room("PisoTronco/Tronco"), "y la de subida vuelve al tronco")
	tree.root.get_node(^"GameState").reset()


func test_holes_drop_to_the_floor_below() -> void:
	await _start()
	await _drop(_in("PisoCopa/Nido", Vector3(-6, 0.5, 4)))
	assert_eq(camera.room, _room("PisoTronco/Rama"), "el hueco del nido cae a la rama")
	await _drop(_in("PisoCopa/Arco", Vector3(6, 0.5, 0)))
	assert_eq(camera.room, _room("PisoTronco/Tronco"), "el de la cámara del arco, al tronco")
	tree.root.get_node(^"GameState").reset()


func test_the_branch_block_opens_the_key_gate() -> void:
	await _start()
	var block := level.get_node(^"PisoTronco/RamaBlock") as PushBlock
	for i in 3:
		assert_true(block.try_push(Vector3.RIGHT), "el bloque avanza")
		await tree.create_timer(0.6).timeout
	assert_true(tree.root.get_node(^"GameState").get_flag(&"qv_west_switch") == true, "queda sobre el interruptor")
	await tree.create_timer(1.0).timeout
	assert_true((level.get_node(^"PisoTronco/RamaKeyGate") as Gate).is_open, "y se abre la reja de la llave")
	tree.root.get_node(^"GameState").reset()


func _feather() -> void:
	var state: Node = tree.root.get_node(^"GameState")
	state.give(Items.get_item(&"feather"))
	state.assign_button(1, &"feather")


func _walk(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	event.strength = 1.0
	Input.parse_input_event(event)


func _jump(action: StringName) -> void:
	_walk(action, true)
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
	_walk(action, false)
	for i in 10:
		await tree.physics_frame


func test_the_timed_root_eye_opens_the_gate_for_a_feather_jump() -> void:
	await _start()
	_feather()
	var gate := level.get_node(^"PisoRaices/RaicesGate") as Gate
	var eye := level.get_node(^"PisoRaices/RootEyeB") as EyeSwitch
	await _drop(_in("PisoRaices/Raices", Vector3(6, 0.5, 4)))
	assert_eq(camera.room, _room("PisoRaices/Raices"))
	assert_true(not gate.is_open, "cerrada")
	var arrow := Projectile.new()
	eye.hurtbox.receive(DamageInfo.make(2, 0.0, arrow))
	arrow.free()
	assert_true(await _until(func() -> bool: return gate.is_open, 2.0), "la flecha al ojo la abre")
	var floor_y := player.global_position.y
	await _jump(&"move_right")
	assert_true(player.global_position.x > _in("PisoRaices/Raices", Vector3(9.2, 0, 0)).x and absf(player.global_position.y - floor_y) < 0.3, "con la pluma salta los huecos hasta la reja (%s)" % player.global_position.snappedf(0.1))
	player.global_position = _in("PisoRaices/Raices", Vector3(0, 0.5, 0))
	assert_true(await _until(func() -> bool: return not gate.is_open, 8.0), "a los segundos se vuelve a cerrar")
	assert_true(not eye.active, "y el ojo se apaga")
	tree.root.get_node(^"GameState").set_flag(&"qv_eyes_step", true)
	assert_true(await _until(func() -> bool: return camera.revealing, 1.0), "la placa del otro lado la muestra con la cámara (11.145)")
	assert_true(await _until(func() -> bool: return gate.is_open, 4.0), "y la abre")
	await _until(func() -> bool: return not camera.revealing, 6.0)
	await tree.create_timer(7.0).timeout
	assert_true(gate.is_open, "y queda abierta")
	tree.root.get_node(^"GameState").reset()


func test_the_new_pits_hurt_and_return_to_the_room() -> void:
	await _start()
	for spec: Array in [["PisoRaices/Raices", Vector3(8, 0.5, 4)], ["PisoRaices/Ojos", Vector3(8, 0.5, -2)]]:
		await _drop(_in(spec[0], Vector3(0, 0.5, 0)))
		await tree.create_timer(0.8).timeout
		var health := player.health.current
		await _drop(_in(spec[0], spec[1]))
		await tree.create_timer(1.5).timeout
		assert_eq(camera.room, _room(spec[0]), "%s: el hueco devuelve a la sala" % spec[0])
		assert_eq(player.health.current, health - 2, "%s: y lastima" % spec[0])
		assert_true(player.global_position.y > _in(spec[0], Vector3.ZERO).y - 0.5, "%s: parado en el piso" % spec[0])
	tree.root.get_node(^"GameState").reset()


func test_the_boss_key_sits_across_a_row_of_pits() -> void:
	await _start()
	_feather()
	tree.root.get_node(^"GameState").set_flag(&"qv_hidden_eye", true)
	var gate := level.get_node(^"PisoRaices/BossKeyGate") as Gate
	assert_true(await _until(func() -> bool: return gate.is_open, 3.0), "el ojo escondido abre el nicho")
	await _drop(_in("PisoRaices/Ojos", Vector3(8, 0.5, 0)))
	assert_eq(camera.room, _room("PisoRaices/Ojos"))
	var floor_y := player.global_position.y
	await _jump(&"move_forward")
	assert_true(player.global_position.z < _in("PisoRaices/Ojos", Vector3(0, 0, -2.6)).z and absf(player.global_position.y - floor_y) < 0.3, "con la pluma llega al nicho de la llave del jefe (%s)" % player.global_position.snappedf(0.1))
	tree.root.get_node(^"GameState").reset()


func _until(condition: Callable, seconds := 15.0) -> bool:
	var until := Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < until:
		if condition.call():
			return true
		await tree.physics_frame
	return false


func _sword(eye: WatcherEye) -> void:
	while not eye.is_dead and eye.is_vulnerable():
		eye.hurtbox.receive(DamageInfo.make(2, 0.0, player))
		await tree.create_timer(0.3).timeout


func _open_eye(eyes: Array[WatcherEye]) -> WatcherEye:
	for eye in eyes:
		if not eye.is_dead and eye.state in [WatcherEye.State.CHARGE, WatcherEye.State.SWEEP]:
			return eye
	return null


func test_the_warden_gets_stuck_in_the_roots_and_falls_to_the_sword() -> void:
	await _start()
	var fight := level.get_node(^"PisoCopa/WardenFight") as ArenaFight
	var warden := fight.get_node(^"Warden") as WatcherEye
	var entry := level.get_node(^"PisoCopa/CopaLocked") as Door
	var bow_door := level.get_node(^"PisoCopa/ArcoDoor") as Door
	tree.root.get_node(^"GameState").set_flag(&"qv_canopy_locked_door", true)
	await tree.create_timer(0.2).timeout
	warden.rest_time = 0.1
	player.global_position = _in("PisoCopa/Vigia", Vector3(0, 0, 2))
	assert_true(await _until(func() -> bool: return warden.state != WatcherEye.State.IDLE), "arranca la pelea")
	assert_true(not entry.is_open, "la puerta de entrada se cierra detrás")
	assert_true(not bow_door.is_open, "la cámara del arco está cerrada")
	warden.hurtbox.receive(DamageInfo.make(2, 0.0, player))
	assert_eq(warden.health.current, warden.health.max_health, "flotando, la espada rebota")
	assert_true(await _until(func() -> bool: return warden.state == WatcherEye.State.STUCK, 20.0), "se tira y queda enganchado")
	assert_true(warden._open < 1.0, "los párpados se abren animados, no de golpe (%.2f)" % warden._open)
	await tree.create_timer(0.3).timeout
	assert_eq(warden._open, 1.0, "y quedan abiertos")
	await _sword(warden)
	assert_true(warden.is_dead, "enganchado, la espada lo vence sin arco")
	assert_true(await _until(func() -> bool: return fight.active), "pelea ganada")
	assert_true(tree.root.get_node(^"GameState").get_flag(&"qv_warden_defeated") == true, "queda el flag")
	assert_true(await _until(func() -> bool: return bow_door.is_open, 6.0), "se abre la cámara del arco")
	assert_true(entry.is_open, "y la puerta de entrada")
	tree.root.get_node(^"GameState").reset()


func test_leaving_the_lair_resets_the_fight() -> void:
	await _start()
	var warden := level.get_node(^"PisoCopa/WardenFight/Warden") as WatcherEye
	tree.root.get_node(^"GameState").set_flag(&"qv_canopy_locked_door", true)
	player.global_position = _in("PisoCopa/Vigia", Vector3(0, 0, 2))
	assert_true(await _until(func() -> bool: return warden.state != WatcherEye.State.IDLE), "arranca la pelea")
	player.global_position = _in("PisoCopa/Copa", Vector3.ZERO)
	assert_true(await _until(func() -> bool: return warden.state == WatcherEye.State.IDLE, 3.0), "fuera de la sala, el ojo vuelve a esperar")
	assert_true((level.get_node(^"PisoCopa/CopaLocked") as Door).is_open, "y la puerta de entrada queda abierta")
	tree.root.get_node(^"GameState").reset()


func test_an_arrow_drops_an_open_eye_for_the_sword() -> void:
	await _start()
	var fight := level.get_node(^"PisoRaices/BossFight") as ArenaFight
	var eyes: Array[WatcherEye] = [fight.get_node(^"EyeWest"), fight.get_node(^"EyeEast")]
	for eye in eyes:
		eye.rest_time = 0.1
	var arrow := (load("res://src/entities/projectile.tscn") as PackedScene).instantiate()
	var shot := func(eye: WatcherEye) -> void: eye.hurtbox.receive(DamageInfo.make(2, 0.0, arrow))
	player.global_position = _in("PisoRaices/Jefe", Vector3(0, 0, 4))
	assert_true(await _until(func() -> bool: return eyes[0].state == WatcherEye.State.DRIFT), "arranca la pelea")
	assert_true(not (level.get_node(^"PisoRaices/BossDoor") as Door).is_open, "la puerta del jefe se cierra")
	shot.call(eyes[0])
	assert_eq(eyes[0].state, WatcherEye.State.DRIFT, "cerrado, la flecha no le hace nada")
	for round in 2:
		assert_true(await _until(func() -> bool: return _open_eye(eyes) != null, 20.0), "un ojo se abre para cargar")
		var open := _open_eye(eyes)
		shot.call(open)
		assert_eq(open.state, WatcherEye.State.DOWN, "la flecha lo derriba")
		await _sword(open)
		assert_true(open.is_dead, "en el piso, la espada lo vence")
		if round == 0:
			var other := eyes[1] if open == eyes[0] else eyes[0]
			assert_true(other.pace > 1.0, "el que queda se apura")
	assert_true(await _until(func() -> bool: return fight.active), "pelea ganada")
	assert_true(tree.root.get_node(^"GameState").get_flag(&"qv_boss_defeated") == true, "queda el flag del jefe")
	assert_true((level.get_node(^"PisoRaices/BossExitPortal") as Portal).visible, "aparece el portal de salida")
	assert_true((fight.get_node_or_null(^"HeartContainer") as Node) != null, "y el contenedor de corazón")
	arrow.free()
	tree.root.get_node(^"GameState").reset()


## 11.141: el muro agrietado llena el paso de pared LA y se ve en las dos caras; una bomba puesta en la cara de la sala lo rompe.
func test_the_nest_cracked_wall_fills_the_passage_and_a_bomb_at_the_face_breaks_it() -> void:
	await _start()
	var wall := level.get_node(^"PisoCopa/NidoCrackedWall") as CrackedWall
	var plug := (wall.wall.get_node(^"Model") as MeshInstance3D).get_aabb()
	assert_true(plug.size.z > 3.4, "el tapón llena los 4 m del paso doble (%.1f)" % plug.size.z)
	var east := wall.global_position + Vector3(2.2, 0.3, 0)
	var bomb: Bomb = preload("res://src/items/bomb/bomb.tscn").instantiate()
	level.add_child(bomb)
	bomb.global_position = east
	await tree.create_timer(2.4).timeout
	assert_true(wall.is_broken, "la bomba en la cara de la Copa lo rompe")
	tree.root.get_node(^"GameState").reset()
