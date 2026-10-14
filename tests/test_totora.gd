extends "res://tests/test_case.gd"
## El Santuario de Totora (D3, 11.30): islas de totora sobre agua honda (el agua es un pozo), dos pisos, el gancho
## cruza las aguas de cuatro celdas de poste a poste.

const LEVEL := "res://levels/totora.tscn"
const MapData := preload("res://src/ui/menus/map_data.gd")
## [sala de donde sale, punto en esa sala, poste, sala a la que llega].
const CROSSINGS := [
	["PisoBajo/Gancho", Vector3(-0.9, 0, 0.5), "PisoBajo/BalsasPost", "PisoBajo/Balsas"],
	["PisoBajo/Balsas", Vector3(-0.9, 0, -2.5), "PisoBajo/GanchoPost", "PisoBajo/Gancho"],
	["PisoAlto/Estanque", Vector3(-4, 0, 0), "PisoAlto/EstanqueStripPost", "PisoAlto/Estanque"],
	["PisoAlto/Estanque", Vector3(6, 0, 0), "PisoAlto/EstanqueWestPost", "PisoAlto/Estanque"],
	["PisoAlto/Mirador", Vector3(-6, 0, 0), "PisoAlto/MiradorPost", "PisoAlto/Mirador"],
	["PisoAlto/Mirador", Vector3(4, 0, 0), "PisoAlto/MiradorBackPost", "PisoAlto/Mirador"],
	["PisoAlto/Tejedores", Vector3(6, 0, 4), "PisoAlto/TejedoresPost", "PisoAlto/Tejedores"],
]

var tree: SceneTree
var level: Node
var player: PlayerCharacter
var camera: TopDownCamera


func _start() -> void:
	tree = Engine.get_main_loop() as SceneTree
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


## Lleva al player a un punto de otra sala sin la caminata de la transición, que lo metería al agua de una franja angosta.
func _enter(at: Vector3) -> void:
	player.global_position = at
	player.velocity = Vector3.ZERO
	await _until(func() -> bool: return player.movement_state.get_active_state().name == &"Transition", 0.6)
	if player.movement_state.get_active_state().name == &"Transition":
		player.movement_state.dispatch("finished")
	player.global_position = at
	player.velocity = Vector3.ZERO
	await tree.create_timer(0.4).timeout


func _until(done: Callable, seconds: float) -> bool:
	var until := Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < until:
		if done.call():
			return true
		await tree.physics_frame
	return done.call()


func _hookshot() -> void:
	var state: Node = tree.root.get_node(^"GameState")
	state.give(Items.get_item(&"hookshot"))
	state.assign_button(0, &"hookshot")


func _fire() -> void:
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


## Cuántas celdas sin piso hay en línea recta desde `from` hacia `toward` antes de volver a pisar.
func _water_run(floor_path: String, from: Vector3, toward: Vector3) -> int:
	var grid := level.get_node(floor_path + "/GridMap") as GridMap
	var local := grid.to_local(from)
	var cell := grid.local_to_map(local) * Vector3i(1, 0, 1)
	var step := Vector3i(roundi(toward.x), 0, roundi(toward.z))
	var count := 0
	for i in 8:
		cell += step
		if grid.get_cell_item(cell) != GridMap.INVALID_CELL_ITEM:
			break
		count += 1
	return count


func test_starts_in_the_landing_with_two_floors() -> void:
	await _start()
	assert_eq(camera.room, _room("PisoBajo/Embarcadero"), "arranca en el embarcadero")
	assert_eq(MapData.rooms_on(tree, 0).size(), 6, "seis salas abajo")
	assert_eq(MapData.rooms_on(tree, 1).size(), 5, "cinco arriba")
	tree.root.get_node(^"GameState").reset()


func test_the_reeds_stairs_go_up_to_the_guardhouse_and_back() -> void:
	await _start()
	player.global_position = _in("PisoBajo/Juncal", Vector3(7.4, 0, -2))
	await tree.create_timer(1.2).timeout
	assert_eq(camera.room, _room("PisoAlto/Garita"), "la escalera del juncal sube a la garita")
	player.global_position = _in("PisoAlto/Garita", Vector3(7.4, 0, -2))
	await tree.create_timer(1.2).timeout
	assert_eq(camera.room, _room("PisoBajo/Juncal"), "y baja")
	tree.root.get_node(^"GameState").reset()


func test_deep_water_hurts_and_returns_to_the_room() -> void:
	await _start()
	for spec: Array in [["PisoBajo/Embarcadero", Vector3(-4, 0.5, -2)], ["PisoAlto/Telar", Vector3(-6, 0.5, -2)]]:
		await _drop(_in(spec[0], Vector3(0, 0.5, 4)))
		await tree.create_timer(0.8).timeout
		var health := player.health.current
		await _drop(_in(spec[0], spec[1]))
		await tree.create_timer(1.5).timeout
		assert_eq(camera.room, _room(spec[0]), "%s: el agua devuelve a la sala" % spec[0])
		assert_eq(player.health.current, health - 2, "%s: y lastima" % spec[0])
		assert_true(player.global_position.y > _in(spec[0], Vector3.ZERO).y - 0.5, "%s: parado en el piso" % spec[0])
	tree.root.get_node(^"GameState").reset()


## 11.167: si el agua le saca el último corazón, muere en la orilla; no sigue cayendo al vacío hasta el game over.
func test_drowning_on_the_last_heart_dies_on_the_floor() -> void:
	await _start()
	var spec := ["PisoBajo/Embarcadero", Vector3(-4, 0.5, -2)]
	await _drop(_in(spec[0], Vector3(0, 0.5, 4)))
	await tree.create_timer(0.8).timeout
	player.health.restore(player.health.max_health, 1)
	player.global_position = _in(spec[0], spec[1])
	player.velocity = Vector3.ZERO
	var stack: Node = tree.root.get_node(^"MenuStack")
	var lowest := INF
	for i in 300:
		lowest = minf(lowest, player.global_position.y)
		if stack.top() is GameOver:
			break
		await tree.physics_frame
	assert_true(player.is_dead, "el agua lo mata")
	assert_true(stack.top() is GameOver, "game over")
	assert_true(player.global_position.y > _in(spec[0], Vector3.ZERO).y - 0.5, "muere parado en el piso (%.1f)" % player.global_position.y)
	assert_true(lowest > _in(spec[0], Vector3.ZERO).y - 6.0, "sin caer al vacío (%.1f)" % lowest)
	(stack.top() as GameOver)._continue.pressed.emit()
	await tree.create_timer(0.5).timeout
	tree.root.get_node(^"GameState").reset()


func test_every_hook_crossing_is_too_wide_to_jump_and_the_hook_crosses_it() -> void:
	await _start()
	_hookshot()
	for spec: Array in CROSSINGS:
		var post := level.get_node(spec[2] as String) as HookPost
		var from := _in(spec[0], spec[1])
		var across := (post.global_position - from) * Vector3(1, 0, 1)
		var axis := Vector3(signf(across.x), 0, 0) if absf(across.x) > absf(across.z) else Vector3(0, 0, signf(across.z))
		var floor_path := (spec[0] as String).get_slice("/", 0)
		var run := _water_run(floor_path, post.global_position - axis * 9.0, axis)
		assert_true(run >= 4, "%s: el agua hasta %s mide %d celdas (el salto largo cruza 3)" % [spec[0], post.name, run])
		await _enter(from)
		var health := player.health.current
		assert_true(post in player.targeting.possible_targets, "%s: %s está al alcance" % [spec[0], post.name])
		player.targeting.set_target(post)
		await _fire()
		await tree.create_timer(0.4).timeout
		player.targeting.clear()
		assert_true(player.global_position.distance_to(post.global_position) < 1.5 and player.health.current == health, "%s: el gancho lleva hasta %s sin caer al agua (%s)" % [spec[0], post.name, player.global_position.snappedf(0.1)])
		assert_eq(camera.room, _room(spec[3]), "%s: llega a %s" % [spec[0], spec[3]])
	tree.root.get_node(^"GameState").reset()


## 11.153: un cruce de gancho nunca pasa por una puerta (del otro lado el poste no se ve); al Estanque se va por un muelle.
func test_the_telar_pier_walks_through_the_north_door_to_the_pond() -> void:
	await _start()
	var grid := level.get_node(^"PisoAlto/GridMap") as GridMap
	var from := grid.local_to_map(grid.to_local(_in("PisoAlto/Telar", Vector3(-4, 0, 4))))
	var to := grid.local_to_map(grid.to_local(_in("PisoAlto/Estanque", Vector3(-4, 0, 4))))
	for z in range(to.z, from.z + 1):
		assert_true(grid.get_cell_item(Vector3i(from.x, 0, z)) != GridMap.INVALID_CELL_ITEM, "hay piso en la celda (%d, %d) del muelle" % [from.x, z])
	await _enter(_in("PisoAlto/Telar", Vector3(-4, 0, 4)))
	var health := player.health.current
	Input.action_press(&"move_forward")
	var arrived := await _until(func() -> bool: return camera.room == _room("PisoAlto/Estanque") and player.is_on_floor(), 6.0)
	Input.action_release(&"move_forward")
	assert_true(arrived and player.health.current == health, "caminando por el muelle llega al Estanque sin caer (%s)" % player.global_position.snappedf(0.1))
	tree.root.get_node(^"GameState").reset()


## 11.154: donde un ojo pide flechas, una vasija de flechas en la misma sala.
func test_every_eye_room_has_an_arrow_pot() -> void:
	await _start()
	var arrows := load("res://data/drops/pot_arrows.tres")
	var rooms := level.find_children("*", "Room", true, false)
	for eye: EyeSwitch in level.find_children("*", "EyeSwitch", true, false):
		var room: Room = null
		for candidate: Room in rooms:
			if candidate.contains(eye.global_position + Vector3.UP):
				room = candidate
		var pots := level.find_children("*", "Breakable", true, false).filter(func(pot: Breakable) -> bool:
			return pot.drops == arrows and room and room.contains(pot.global_position + Vector3.UP))
		assert_true(pots.size() >= 1, "%s: hay vasijas de flechas en su sala" % eye.name)
	tree.root.get_node(^"GameState").reset()


func test_beating_amaru_opens_the_hookshot_room() -> void:
	tree = Engine.get_main_loop() as SceneTree
	tree.root.get_node(^"GameState").reset()
	await _start()
	var door := level.get_node(^"PisoBajo/GanchoDoor") as Door
	assert_true(not door.is_open, "la puerta de la cámara del gancho arranca cerrada")
	tree.root.get_node(^"GameState").set_flag(&"tt_amaru_defeated", true)
	await _start()
	door = level.get_node(^"PisoBajo/GanchoDoor") as Door
	assert_true(await _until(func() -> bool: return door.is_open, 2.0), "vencido el Amaru, abre")
	tree.root.get_node(^"GameState").reset()


func test_the_timed_eye_opens_the_boss_key_gate_and_the_hole_is_the_way_out() -> void:
	tree = Engine.get_main_loop() as SceneTree
	tree.root.get_node(^"GameState").reset()
	await _start()
	var gate := level.get_node(^"PisoAlto/BossKeyGate") as Gate
	var eye := level.get_node(^"PisoAlto/TejedoresEye") as EyeSwitch
	assert_true(not gate.is_open, "la reja de la llave del jefe arranca cerrada")
	var arrow := Projectile.new()
	eye.hurtbox.receive(DamageInfo.make(2, 0.0, arrow))
	arrow.free()
	assert_true(await _until(func() -> bool: return gate.is_open, 2.0), "la flecha al ojo la abre")
	assert_true(await _until(func() -> bool: return not gate.is_open, 9.0), "y a los segundos se cierra")
	await _drop(_in("PisoAlto/Tejedores", Vector3(-4, 0.5, -4)))
	assert_eq(camera.room, _room("PisoBajo/Gancho"), "el hueco junto al cofre cae a la cámara del gancho")
	tree.root.get_node(^"GameState").reset()
