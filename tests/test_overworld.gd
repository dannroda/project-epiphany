extends "res://tests/test_case.gd"

const LEVEL := "res://levels/overworld.tscn"


func _walk(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	event.strength = 1.0
	Input.parse_input_event(event)


## Camina hasta que `done` se cumpla. Devuelve si llegó y si en algún momento cayó por debajo del piso.
func _walk_until(tree: SceneTree, player: PlayerCharacter, action: StringName, done: Callable) -> Array:
	_walk(action, true)
	var until := Time.get_ticks_msec() + 12000
	var fell := false
	while Time.get_ticks_msec() < until and not done.call():
		await tree.physics_frame
		fell = fell or player.global_position.y < -0.5
	_walk(action, false)
	for i in 3:
		await tree.physics_frame
	return [done.call(), fell]


func test_walk_every_zone_without_falling_or_sticking() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	state.reset()
	state.set_flag(&"ow_shrine_cracked_wall", true)
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	for enemy in tree.get_nodes_in_group(&"enemies"):
		enemy.free()
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	await tree.create_timer(0.5).timeout
	assert_eq(AreaZone._current.display_name, "Claro del inicio", "arranca en el claro")
	var at := func(axis: int, sign_: float, value: float) -> Callable:
		return func() -> bool: return (player.global_position[axis] - value) * sign_ >= 0.0
	var route := [
		[&"move_forward", at.call(2, -1.0, 0.0), "Pradera"],
		[&"move_left", at.call(0, -1.0, -24.0), "Cueva"],
		[&"move_forward", at.call(2, -1.0, -16.0), "Santuario"],
		[&"move_right", at.call(0, 1.0, 0.0), "Entrada del templo"],
		[&"move_backward", at.call(2, 1.0, 0.0), "Pradera"],
		[&"move_right", at.call(0, 1.0, 24.0), "Arboleda"],
		[&"move_forward", at.call(2, -1.0, -14.0), "Risco del ojo"],
		[&"move_backward", at.call(2, 1.0, 0.0), "Arboleda"],
		[&"move_left", at.call(0, -1.0, 0.0), "Pradera"],
		[&"move_backward", at.call(2, 1.0, 16.0), "Claro del inicio"],
		[&"move_left", at.call(0, -1.0, -24.0), "Gruta oculta"],
	]
	for leg in route:
		var result: Array = await _walk_until(tree, player, leg[0], leg[1])
		assert_true(result[0], "llega a %s sin trabarse (quedó en %s)" % [leg[2], player.global_position.snappedf(0.1)])
		assert_eq(result[1], false, "no cae camino a %s" % leg[2])
		assert_eq(AreaZone._current.display_name if AreaZone._current else "", leg[2], "el HUD nombra la zona")
	assert_eq(tree.get_first_node_in_group(&"hud").area_label.text, "Gruta oculta", "el cartel muestra la última zona")
	state.reset()


func test_abyss_stops_the_player_but_not_arrows() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.get_node(^"GameState").reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	await tree.physics_frame
	var space := (tree.current_scene as Node3D).get_world_3d().direct_space_state
	var low := PhysicsRayQueryParameters3D.create(Vector3(24, 0.3, -14), Vector3(24, 0.3, -22), 1)
	assert_true(not space.intersect_ray(low).is_empty(), "a la altura del player el abismo frena")
	var high := PhysicsRayQueryParameters3D.create(Vector3(24, 1.0, -14), Vector3(24, 1.0, -21), 1)
	assert_true(space.intersect_ray(high).is_empty(), "a la altura de una flecha pasa por arriba")
	tree.root.get_node(^"GameState").reset()
