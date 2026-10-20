extends "res://tests/test_case.gd"
## 11.34 paso 6: piedras de técnica y muñeco de práctica. Leer la piedra enseña la técnica y muestra el cartel; el
## muñeco se fija, avisa golpes de mentira para el contraataque y aguanta lo que le peguen.

const LEVEL := "res://levels/test.tscn"
const STONE := preload("res://src/world/technique_stone.tscn")
const DUMMY := preload("res://src/world/practice_dummy.tscn")
const COUNTER := preload("res://data/techniques/counter.tres")


func _level() -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	var state := tree.root.get_node(^"GameState")
	state.reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	for enemy in tree.get_nodes_in_group(&"enemies"):
		enemy.free()
	use_gamepad()
	for i in 300:
		if player.movement_state.get_active_state().name == &"Idle":
			break
		await tree.physics_frame
	return [tree, player, state]


func _until(tree: SceneTree, done: Callable, frames := 240) -> bool:
	for i in frames:
		if done.call():
			return true
		await tree.physics_frame
	return done.call()


func test_reading_the_stone_teaches_the_technique() -> void:
	var setup: Array = await _level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var state: Node = setup[2]
	var stone := STONE.instantiate() as TechniqueStone
	stone.technique = COUNTER
	tree.current_scene.add_child(stone)
	stone.global_position = player.global_position + Vector3(0, 0, 2)
	await tree.process_frame
	assert_eq(stone.glow.current_animation, &"idle", "brilla mientras no se aprendió")
	stone._read(player)
	await tree.process_frame
	assert_true(state.get_flag(&"ow_tech_counter") == true, "enseña el contraataque")
	var stack: Node = tree.root.get_node(^"MenuStack")
	var screen: Node = stack.top()
	assert_true(screen != null and screen.get(&"technique") == COUNTER, "con el cartel de técnica nueva")
	assert_eq(screen.text_box.cue, "counter", "y su texto")
	assert_true(not stone.glow.is_playing() or stone.glow.current_animation != &"idle", "ya no brilla")
	stack.pop()
	await tree.process_frame
	stone._read(player)
	await tree.process_frame
	assert_true(stack.top() != null and stack.top().get(&"technique") == COUNTER, "releerla lo vuelve a mostrar")
	stack.pop()
	state.reset()


func test_the_dummy_can_be_countered() -> void:
	var setup: Array = await _level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var state: Node = setup[2]
	state.set_flag(&"ow_tech_counter", true)
	var dummy := DUMMY.instantiate() as PracticeDummy
	tree.current_scene.add_child(dummy)
	dummy.global_position = player.global_position + Vector3(0, 0, 2.2)
	dummy.look_at(dummy.global_position + Vector3(0, 0, 1), Vector3.UP)
	for i in 3:
		await tree.physics_frame
	var lock := InputEventAction.new()
	lock.action = &"z-lock"
	lock.pressed = true
	Input.parse_input_event(lock)
	Input.action_press(&"z-lock")
	assert_true(await _until(tree, func() -> bool: return player.targeting.current == dummy, 30), "el muñeco se fija")
	assert_true(await _until(tree, func() -> bool: return player.counter.is_open(), 300), "avisa un golpe y abre la ventana")
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = &"attack"
		event.pressed = pressed
		Input.parse_input_event(event)
	assert_true(await _until(tree, func() -> bool: return dummy.hits > 0, 90), "el contraataque le pega")
	Input.action_release(&"z-lock")
	TimeScale.clear()
	await tree.physics_frame
	state.reset()


func test_the_dummy_takes_the_sword_beam() -> void:
	var setup: Array = await _level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var state: Node = setup[2]
	state.set_flag(&"ow_tech_beam", true)
	var dummy := DUMMY.instantiate() as PracticeDummy
	dummy.period = 1000.0
	tree.current_scene.add_child(dummy)
	dummy.global_position = player.global_position + Vector3(4, 0, 0)
	player.model.look_at(player.model.global_position - Vector3(1, 0, 0), Vector3.UP)
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = &"attack"
		event.pressed = pressed
		Input.parse_input_event(event)
	assert_true(await _until(tree, func() -> bool: return dummy.hits > 0, 60), "el rayo le llega")
	state.reset()


func _reaches(map: RID, from: Vector3, to: Vector3) -> bool:
	var a := NavigationServer3D.map_get_closest_point(map, from)
	var b := NavigationServer3D.map_get_closest_point(map, to)
	var path := NavigationServer3D.map_get_path(map, a, b, true)
	return b.distance_to(to) < 0.6 and not path.is_empty() and path[-1].distance_to(b) < 0.6


func _flat_under(space: PhysicsDirectSpaceState3D, body: Node3D, skip: Array[RID]) -> bool:
	var ys: Array[float] = []
	for dx in [-0.8, 0.0, 0.8]:
		for dz in [-0.8, 0.0, 0.8]:
			var at := body.global_position + Vector3(dx, 0, dz)
			var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 1.2, at + Vector3.DOWN * 1.5)
			query.exclude = skip
			var hit := space.intersect_ray(query)
			if not hit:
				return false
			ys.append((hit.position as Vector3).y)
	return ys.max() - ys.min() < 0.25 and absf(ys.max() - body.global_position.y) < 0.2


## En el overworld, cada piedra con su muñeco al lado y en piso plano, y se llega con lo que pide: la del contraataque
## desde el inicio; la de la picada cruzando con la pluma el abismo de la cornisa del Claro; la del rayo con el gancho.
func test_the_overworld_stones_are_reached_with_their_item() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	state.reset()
	tree.change_scene_to_file("res://levels/overworld.tscn")
	await tree.scene_changed
	for i in 10:
		await tree.physics_frame
	var level := tree.current_scene
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	var start := player.global_position
	(level.get_node(^"RavineBridge") as Bridge).raise(false)
	for i in 4:
		await tree.physics_frame
	var map := player.get_world_3d().navigation_map
	var space := player.get_world_3d().direct_space_state
	var stones := {}
	var skip: Array[RID] = []
	for stone: TechniqueStone in level.find_children("*", "TechniqueStone", true, false):
		stones[stone.technique.flag] = stone
		var dummy := stone.get_parent().get_node(String(stone.name).replace("Stone", "Dummy")) as Node3D
		assert_true(dummy is PracticeDummy and dummy.global_position.distance_to(stone.global_position) < 7.0, "%s tiene su muñeco al lado" % stone.name)
		skip.append_array([stone.get_rid(), (dummy as CollisionObject3D).get_rid()])
	assert_eq(stones.keys().size(), 3, "tres piedras en el overworld")
	for stone: TechniqueStone in stones.values():
		var dummy := stone.get_parent().get_node(String(stone.name).replace("Stone", "Dummy")) as Node3D
		player.global_position = stone.global_position + Vector3.UP
		for i in 30:
			await tree.physics_frame
		assert_true(_flat_under(space, stone, skip) and _flat_under(space, dummy, skip), "%s y su muñeco en piso plano" % stone.name)
	var meadow: Node3D = stones[Counter.LEARNED]
	var grove: Node3D = stones[Plunging.LEARNED]
	var summit: Node3D = stones[&"ow_tech_beam"]
	assert_true(_reaches(map, start, meadow.global_position), "a la del contraataque se llega caminando")
	var ledge := Vector3(-44, 2.6, 24)
	var landing := Vector3(-40, 2.6, 24)
	assert_true(_reaches(map, start, ledge), "a la cornisa del Claro se llega caminando")
	assert_true(not _reaches(map, start, grove.global_position), "a la de la picada no se llega caminando")
	assert_true(_reaches(map, landing, grove.global_position), "sí del otro lado del abismo de la cornisa (pluma)")
	var post := level.get_node(^"CumbrePost") as Node3D
	assert_true(not _reaches(map, start, summit.global_position), "a la del rayo no se llega caminando")
	assert_true(_reaches(map, post.global_position + Vector3(0.4, 0, -1.5), summit.global_position), "sí desde el poste de la Cumbre (gancho)")
	state.reset()
