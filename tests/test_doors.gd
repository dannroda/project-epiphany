extends "res://tests/test_case.gd"

const LEVEL := "res://levels/test_rooms.tscn"
const DOOR := preload("res://src/world/door.tscn")
const SLOT := 9


func _setup() -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	state.reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	for i in 4:
		await tree.physics_frame
	var level := tree.current_scene
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	player.health.make_invulnerable(999.0)
	return [tree, state, player, level]


func _walk_until(tree: SceneTree, action: StringName, done: Callable, seconds := 8.0) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	event.strength = 1.0
	Input.parse_input_event(event)
	var until := Time.get_ticks_msec() + seconds * 1000.0
	while Time.get_ticks_msec() < until and not done.call():
		await tree.physics_frame
	var release := InputEventAction.new()
	release.action = action
	Input.parse_input_event(release)


func test_shutter_closes_until_room_is_cleared() -> void:
	var setup: Array = await _setup()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[2]
	var level: Node = setup[3]
	var shutter: Door = level.get_node(^"ShutterAB")
	var room_b: Room = level.get_node(^"RoomB")
	var skeleton: Enemy = level.get_node(^"Skeleton")
	skeleton.bt_player.active = false
	assert_eq(shutter.is_open, true, "la persiana arranca abierta")
	await _walk_until(tree, &"move_forward", func() -> bool: return player.global_position.z < -7.5)
	await tree.create_timer(1.0).timeout
	assert_eq(shutter.is_open, false, "al entrar con un esqueleto vivo, se cierra")
	assert_eq(shutter.shape.disabled, false, "y bloquea el paso")
	assert_eq(room_b.locked, true)
	skeleton.health.damage(999)
	await tree.create_timer(1.0).timeout
	assert_eq(shutter.is_open, true, "al matar al último, se abre")
	assert_eq(shutter.shape.disabled, true)
	setup[1].reset()


func test_a_room_left_right_away_does_not_lock() -> void:
	var setup: Array = await _setup()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[2]
	var level: Node = setup[3]
	var room_a: Room = level.get_node(^"RoomA")
	var room_b: Room = level.get_node(^"RoomB")
	var shutter: Door = level.get_node(^"ShutterAB")
	(level.get_node(^"Skeleton") as Enemy).bt_player.active = false
	var spot := room_a.bounds().get_center()
	player.global_position = Vector3(spot.x, room_a.floor_y() + 0.1, spot.y)
	room_b.mark_entered()
	await tree.create_timer(room_b.lock_delay + 0.4).timeout
	assert_eq(room_b.locked, false, "si el player ya se fue, la sala vacía no se cierra")
	assert_eq(shutter.is_open, true)
	room_b.mark_entered()
	tree.reload_current_scene()
	await tree.create_timer(room_b.lock_delay + 0.4).timeout
	setup[1].reset()


func test_clearing_the_room_shows_its_shutter_opening() -> void:
	var setup: Array = await _setup()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[2]
	var level: Node = setup[3]
	var shutter: Door = level.get_node(^"ShutterAB")
	var skeleton: Enemy = level.get_node(^"Skeleton")
	var camera: TopDownCamera = level.get_node(^"TopDownCamera")
	skeleton.bt_player.active = false
	await _walk_until(tree, &"move_forward", func() -> bool: return player.global_position.z < -7.5)
	await tree.create_timer(1.0).timeout
	TopDownCamera.unlock_reveals = true
	skeleton.health.damage(999)
	var until := Time.get_ticks_msec() + 2000
	while Time.get_ticks_msec() < until and not camera.revealing:
		await tree.process_frame
	assert_true(camera.revealing, "al limpiar la sala la cámara muestra la persiana")
	assert_true(tree.paused, "con el juego en pausa")
	while camera.revealing:
		await tree.process_frame
	assert_eq(shutter.is_open, true, "y se abrió")
	assert_eq(tree.paused, false)
	setup[1].reset()


func test_locked_door_needs_key_and_stays_open() -> void:
	var setup: Array = await _setup()
	var tree: SceneTree = setup[0]
	var state: Node = setup[1]
	var player: PlayerCharacter = setup[2]
	var level: Node = setup[3]
	var saves: Node = tree.root.get_node(^"SaveManager")
	var stack: Node = tree.root.get_node(^"MenuStack")
	var before := ConfigFile.new()
	state.write_to(before)
	var door: Door = level.get_node(^"LockedBC")
	assert_eq(door.interactable.prompt, "PROMPT_OPEN")
	door.interactable.interact(player)
	assert_eq(door.is_open, false, "sin llave no se abre")
	assert_true(stack.top() is TextBox, "avisa que está cerrada con llave")
	stack.pop()
	state.give(Items.get_item(&"small_key"))
	state.give(Items.get_item(&"small_key"))
	assert_eq(state.current_dungeon_state().small_keys, 2)
	door.interactable.interact(player)
	assert_eq(door.is_open, true, "con llave se abre")
	assert_true(door.swing.is_playing(), "se abre con animación, no de golpe")
	assert_eq(state.current_dungeon_state().small_keys, 1, "y gasta una")
	assert_eq(state.get_flag(&"d1_test_locked_door"), true)
	await tree.create_timer(0.8).timeout
	assert_eq(door.shape.disabled, true, "la colisión se apaga al terminar de abrirse")

	assert_eq(saves.save_game(SLOT), OK)
	state.reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	assert_eq(await saves.load_game(SLOT), OK)
	await tree.process_frame
	door = tree.current_scene.get_node(^"LockedBC")
	assert_eq(door.is_open, true, "sigue abierta tras guardar y cargar")
	state.read_from(before)
	await tree.process_frame
	assert_eq(door.is_open, false, "una partida anterior la vuelve a cerrar")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saves.slot_path(SLOT)))
	state.reset()


func test_boss_door_needs_boss_key_without_spending_it() -> void:
	var setup: Array = await _setup()
	var tree: SceneTree = setup[0]
	var state: Node = setup[1]
	var player: PlayerCharacter = setup[2]
	var stack: Node = tree.root.get_node(^"MenuStack")
	var door: Door = DOOR.instantiate()
	door.kind = Door.Kind.BOSS
	door.flag = &"d1_test_locked_door"
	tree.current_scene.add_child(door)
	door.interactable.interact(player)
	assert_eq(door.is_open, false, "sin la llave del jefe no se abre")
	stack.pop()
	state.give(Items.get_item(&"small_key"))
	door.interactable.interact(player)
	assert_eq(door.is_open, false, "una llave chica no sirve")
	stack.pop()
	state.give(Items.get_item(&"boss_key"))
	door.interactable.interact(player)
	assert_eq(door.is_open, true, "con la llave del jefe se abre")
	assert_eq(state.current_dungeon_state().has_boss_key, true, "y no se gasta")
	state.reset()


func _stub_switch(tree: SceneTree) -> Node:
	var script := GDScript.new()
	script.source_code = "extends Node\nsignal activated\nsignal deactivated\nvar active := false\n\nfunc set_on(on: bool) -> void:\n\tactive = on\n\tif on:\n\t\tactivated.emit()\n\telse:\n\t\tdeactivated.emit()\n"
	script.reload()
	var node := Node.new()
	node.set_script(script)
	tree.current_scene.add_child(node)
	return node


func test_switch_door_opens_and_can_close_again() -> void:
	var setup: Array = await _setup()
	var tree: SceneTree = setup[0]
	var first := _stub_switch(tree)
	var second := _stub_switch(tree)
	var door: Door = DOOR.instantiate()
	door.kind = Door.Kind.SWITCH
	door.stays_open = false
	door.switches.assign([NodePath("../" + first.name), NodePath("../" + second.name)])
	door.condition = Wiring.Condition.ANY
	tree.current_scene.add_child(door)
	assert_eq(door.is_open, false)
	first.set_on(true)
	assert_eq(door.is_open, true, "ANY: con uno alcanza")
	first.set_on(false)
	assert_eq(door.is_open, false, "y si no es permanente, se vuelve a cerrar")
	setup[1].reset()


## 11.141/11.145: con las paredes LA el recorte sur pasa la altura de la hoja; la hoja no se estira ni sale el candado.
func test_a_south_cut_taller_than_the_leaf_leaves_the_door_alone() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.get_node(^"GameState").reset()
	var door := DOOR.instantiate() as Door
	door.kind = Door.Kind.LOCKED
	door.flag = &"test_south_cut"
	tree.root.add_child(door)
	var mark := door.get_node(^"SouthMark") as Sprite3D
	door.south_cut = 0.4
	assert_true(door.leaf.scale.y < 1.0 and mark.visible, "un recorte bajo baja la hoja y muestra el candado")
	door.south_cut = 3.6
	assert_eq(door.leaf.scale.y, 1.0, "uno más alto que la hoja no la estira")
	assert_true(not mark.visible, "ni muestra el candado")
	door.free()
