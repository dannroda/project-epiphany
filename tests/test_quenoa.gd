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
	assert_eq(camera.offset, Vector3(0, 28, 10.6), "la cámara de la escena, no la de por defecto")
	assert_eq(MapData.rooms_on(tree, 0).size(), 4, "cuatro salas en el tronco")
	assert_eq(MapData.rooms_on(tree, 1).size(), 4, "cuatro en la copa")
	assert_eq(MapData.rooms_on(tree, -1).size(), 3, "tres en las raíces")
	tree.root.get_node(^"GameState").reset()


func test_stairs_go_up_to_the_canopy_and_back() -> void:
	await _start()
	player.global_position = Vector3(36, 0, 0.6)
	await tree.create_timer(1.2).timeout
	assert_eq(camera.room, _room("PisoCopa/Copa"), "la escalera sube a la copa")
	assert_true(absf(player.global_position.y - 8.0) < 0.5, "arriba (y %.1f)" % player.global_position.y)
	player.global_position = Vector3(36, 8, 0.6)
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
	player.global_position = Vector3(0.6, 0, 20)
	await tree.create_timer(1.2).timeout
	assert_eq(camera.room, _room("PisoRaices/Raices"), "la bajada lleva a las raíces")
	player.global_position = Vector3(0.6, -8, 12)
	await tree.create_timer(1.2).timeout
	assert_eq(camera.room, _room("PisoTronco/Tronco"), "y la de subida vuelve al tronco")
	tree.root.get_node(^"GameState").reset()


func test_holes_drop_to_the_floor_below() -> void:
	await _start()
	await _drop(Vector3(6, 8.5, 12))
	assert_eq(camera.room, _room("PisoTronco/Rama"), "el hueco del nido cae a la rama")
	await _drop(Vector3(18, 8.5, 24))
	assert_eq(camera.room, _room("PisoTronco/Tronco"), "el de la guarida del vigía, al tronco")
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
	var fight := level.get_node(^"PisoCopa/WardenFight") as EyeFight
	var warden := fight.get_node(^"Warden") as WatcherEye
	var shutter := level.get_node(^"PisoCopa/VigiaShutter") as Door
	warden.rest_time = 0.1
	player.global_position = Vector3(12, 8, 28)
	assert_true(await _until(func() -> bool: return warden.state != WatcherEye.State.IDLE), "arranca la pelea")
	assert_true(not shutter.is_open, "la puerta se cierra detrás")
	warden.hurtbox.receive(DamageInfo.make(2, 0.0, player))
	assert_eq(warden.health.current, warden.health.max_health, "flotando, la espada rebota")
	assert_true(await _until(func() -> bool: return warden.state == WatcherEye.State.STUCK, 20.0), "se tira y queda enganchado")
	await _sword(warden)
	assert_true(warden.is_dead, "enganchado, la espada lo vence sin arco")
	assert_true(await _until(func() -> bool: return fight.active), "pelea ganada")
	assert_true(tree.root.get_node(^"GameState").get_flag(&"qv_warden_defeated") == true, "queda el flag")
	assert_true(await _until(func() -> bool: return (level.get_node(^"PisoCopa/BowGate") as Gate).is_open, 4.0), "se abre la reja del arco")
	assert_true(shutter.is_open, "y la puerta")
	tree.root.get_node(^"GameState").reset()


func test_leaving_the_lair_resets_the_fight() -> void:
	await _start()
	var warden := level.get_node(^"PisoCopa/WardenFight/Warden") as WatcherEye
	player.global_position = Vector3(12, 8, 28)
	assert_true(await _until(func() -> bool: return warden.state != WatcherEye.State.IDLE), "arranca la pelea")
	await _drop(Vector3(18, 8.5, 24))
	assert_eq(warden.state, WatcherEye.State.IDLE, "cayó por el hueco: el ojo vuelve a esperar")
	assert_true((level.get_node(^"PisoCopa/VigiaShutter") as Door).is_open, "y la puerta queda abierta")
	tree.root.get_node(^"GameState").reset()


func test_an_arrow_drops_an_open_eye_for_the_sword() -> void:
	await _start()
	var fight := level.get_node(^"PisoRaices/BossFight") as EyeFight
	var eyes: Array[WatcherEye] = [fight.get_node(^"EyeWest"), fight.get_node(^"EyeEast")]
	for eye in eyes:
		eye.rest_time = 0.1
	var arrow := (load("res://src/entities/projectile.tscn") as PackedScene).instantiate()
	var shot := func(eye: WatcherEye) -> void: eye.hurtbox.receive(DamageInfo.make(2, 0.0, arrow))
	player.global_position = Vector3(36, -8, 28)
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
