extends "res://tests/test_case.gd"
## Salas del templo (M8), una prueba por tarea.

const LEVEL := "res://levels/temple.tscn"

var tree: SceneTree
var state: Node
var level: Node
var player: PlayerCharacter


func _start(items := []) -> void:
	tree = Engine.get_main_loop() as SceneTree
	state = tree.root.get_node(^"GameState")
	state.reset()
	for entry in items:
		state.give(Items.get_item(entry[0]), entry[1])
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	await tree.create_timer(0.3).timeout
	level = tree.current_scene
	player = tree.get_first_node_in_group(&"player") as PlayerCharacter
	player.health.invulnerability_time = 0.0


func _walk(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	event.strength = 1.0
	Input.parse_input_event(event)


func _walk_until(action: StringName, done: Callable) -> bool:
	_walk(action, true)
	var until := Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < until and not done.call():
		await tree.physics_frame
	_walk(action, false)
	await tree.physics_frame
	return done.call()


func _push(block_name: NodePath, directions: Array) -> void:
	var block := level.get_node(block_name) as PushBlock
	for direction in directions:
		assert_true(block.try_push(direction), "%s avanza hacia %s" % [block_name, direction])
		await tree.create_timer(0.6).timeout


func _kill(names: Array) -> void:
	for enemy_name in names:
		var enemy := level.get_node(enemy_name) as Enemy
		enemy.health.invulnerability_time = 0.0
		enemy.health.damage(100)


func _door(door_name: NodePath) -> Door:
	return level.get_node(door_name) as Door


func test_rooms_1_2_vestibule_to_the_hub() -> void:
	await _start()
	var camera := level.get_node(^"TopDownCamera") as TopDownCamera
	assert_eq(state.current_dungeon, &"d1", "templo = mazmorra 1")
	assert_eq(camera.room, level.get_node(^"Vestibulo"), "arranca en el vestíbulo")
	assert_eq(_door(^"VestibuleDoor").is_open, false, "la puerta al hub espera el interruptor")
	player.global_position = Vector3(16, 0, 60)
	await _push(^"VestibuleBlock", [Vector3.RIGHT, Vector3.RIGHT, Vector3.RIGHT, Vector3.RIGHT, Vector3.FORWARD, Vector3.FORWARD])
	await tree.create_timer(0.8).timeout
	assert_eq(_door(^"VestibuleDoor").is_open, true, "el bloque en el interruptor abre la puerta")

	player.global_position = Vector3(24, 0, 59)
	assert_true(await _walk_until(&"move_forward", func() -> bool: return player.global_position.z <= 52.0), "camina hasta el hub")
	await tree.create_timer(1.0).timeout
	assert_eq(camera.room, level.get_node(^"Hub"), "entra al hub")
	assert_eq(_door(^"VestibuleDoor").is_open, true, "sur: libre")
	assert_eq(_door(^"HubShutterW").is_open, false, "oeste: persiana cerrada con los esqueletos")
	assert_eq(_door(^"HubLockedE").is_open, false, "este: con llave")
	assert_eq(_door(^"HubLockedE").kind, Door.Kind.LOCKED)
	assert_eq(_door(^"HubSeal").is_open, false, "norte: el sello, cerrado")
	_kill([^"HubSkeleton1", ^"HubSkeleton2"])
	await tree.create_timer(0.8).timeout
	assert_eq(_door(^"HubShutterW").is_open, true, "sin esqueletos se abre la persiana")
	state.reset()
