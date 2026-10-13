extends "res://tests/test_case.gd"
## El templo rediseñado (GDD §8, 11.113): hub con cuatro alas, salas de 14 × 10 m.

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


func test_fourteen_rooms_that_fit_the_camera() -> void:
	await _start()
	var rooms := level.find_children("*", "Room", true, false)
	assert_eq(rooms.size(), 14, "catorce salas")
	for room: Room in rooms:
		var size := room.bounds().size
		assert_true(size.y <= 10.0 and (size.x <= 14.0 or room.boss_room), "%s entra en pantalla (%s)" % [room.name, size])
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


func test_the_feather_wing_pits_and_eye() -> void:
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
	state.set_flag(&"te_eye_feather", true)
	assert_true((_node("FeatherEye") as FloorSwitch).active, "la placa del ojo de la pluma")
	state.reset()


func test_the_bow_wing_needs_a_bomb_and_arrows() -> void:
	await _start()
	var wall := _node("ArcoCrackedWall") as CrackedWall
	var explosion := (load("res://src/items/bomb/explosion.tscn") as PackedScene).instantiate() as Node3D
	level.add_child(explosion)
	explosion.global_position = wall.global_position + Vector3(-1, 0.3, 0)
	assert_true(await _until(func() -> bool: return wall.is_broken, 2.0), "la bomba abre el paso al ojo del arco")
	var gate := _node("BowKeyGate") as Gate
	gate.reveal_on_open = false
	_arrow(_node("BowKeyEye") as EyeSwitch)
	assert_true(await _until(func() -> bool: return gate.is_open, 3.0), "la flecha al ojo abre el nicho de la llave")
	_arrow(_node("BowEye") as EyeSwitch)
	assert_true(state.get_flag(&"te_eye_bow") == true, "el otro ojo enciende el del sello")
	state.reset()


func test_the_four_eyes_open_the_seal() -> void:
	await _start()
	var seal := _node("HubSeal") as Door
	for flag in [&"te_eye_feather", &"te_eye_bow", &"te_eye_hook"]:
		state.set_flag(flag, true)
	await tree.create_timer(0.5).timeout
	assert_true(not seal.is_open, "con tres ojos sigue cerrado")
	state.set_flag(&"te_eye_mirror", true)
	assert_true(await _until(func() -> bool: return seal.is_open, 3.0), "con los cuatro se abre la antesala")
	state.reset()


func test_the_combined_room_guards_the_boss_key() -> void:
	await _start()
	_feather()
	var gate := _node("BossKeyGate") as Gate
	gate.reveal_on_open = false
	state.set_flag(&"te_combined_eye", true)
	await tree.create_timer(0.5).timeout
	assert_true(not gate.is_open, "falta el haz")
	state.set_flag(&"te_combined_crystal", true)
	assert_true(await _until(func() -> bool: return gate.is_open, 3.0), "ojo y cristal abren el nicho")
	await _drop(_in("Combinada", Vector3(4, 0.5, 3)))
	assert_eq(camera.room, _room("Combinada"))
	await tree.create_timer(0.8).timeout
	player.global_position = _in("Combinada", Vector3(0, 0.5, 2))
	await tree.create_timer(0.4).timeout
	await _jump(&"move_forward")
	assert_true(player.global_position.z < _in("Combinada", Vector3(0, 0, -1)).z and player.global_position.y > -0.3, "con la pluma salta el hueco hasta el nicho (%s)" % player.global_position.snappedf(0.1))
	state.reset()


func test_the_boss_uses_the_temple_flags() -> void:
	await _start()
	var arena := level.get_node(^"BossArena")
	assert_eq(arena.defeated_flag, &"te_boss_defeated")
	assert_eq((level.get_node(^"BossExitPortal") as Portal).required_flag, &"te_boss_defeated")
	assert_true(_room("Jefe").boss_room)
	state.reset()
