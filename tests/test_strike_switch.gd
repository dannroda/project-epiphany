extends "res://tests/test_case.gd"
## La placa de golpe fuerte (11.193): FloorSwitch en STRIKE solo se activa con un golpe fuerte (el martillazo); ni la
## espada ni pisarla la aprietan. Queda resuelta.

const LEVEL := "res://levels/test/test.tscn"
const SWITCH := "res://src/world/floor_switch.tscn"

var tree: SceneTree
var state: Node
var player: PlayerCharacter


func _start() -> void:
	tree = Engine.get_main_loop() as SceneTree
	state = tree.root.get_node(^"GameState")
	state.reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	for i in 3:
		await tree.physics_frame
	for enemy in tree.get_nodes_in_group(&"enemies"):
		enemy.queue_free()
	player = tree.get_first_node_in_group(&"player") as PlayerCharacter
	use_gamepad()
	state.give(Items.get_item(&"hammer"))
	state.assign_button(0, &"hammer")


func _switch(at: Vector3, flag := &"") -> FloorSwitch:
	var switch := (load(SWITCH) as PackedScene).instantiate() as FloorSwitch
	switch.mode = FloorSwitch.Mode.STRIKE
	switch.flag = flag
	tree.current_scene.add_child(switch)
	switch.global_position = at
	return switch


func _face_and_press(target: Vector3, action: StringName) -> void:
	player.global_position = target + Vector3(0, 0, 1.2)
	player.velocity = Vector3.ZERO
	player.model.look_at(player.model.global_position + Vector3.BACK, Vector3.UP)
	for i in 3:
		await tree.physics_frame
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
	await tree.create_timer(1.4).timeout


func test_only_a_strong_hit_presses_the_strike_plate() -> void:
	await _start()
	var switch := _switch(player.global_position + Vector3(4, 0, 0))
	await tree.physics_frame
	assert_eq((switch.get_node(^"Plate") as MeshInstance3D).mesh, switch.strike_plate, "tiene su placa de cobre")
	player.global_position = switch.global_position
	for i in 20:
		await tree.physics_frame
	assert_true(not switch.active, "pisarla no hace nada")
	await _face_and_press(switch.global_position, &"attack")
	assert_true(not switch.active, "la espada no la aprieta")
	await _face_and_press(switch.global_position, &"item_1")
	assert_true(switch.active, "el martillazo sí")
	player.global_position += Vector3(6, 0, 0)
	await tree.create_timer(0.5).timeout
	assert_true(switch.active, "y queda apretada")
	switch.free()


func test_the_other_plates_ignore_hits() -> void:
	await _start()
	var switch := (load(SWITCH) as PackedScene).instantiate() as FloorSwitch
	tree.current_scene.add_child(switch)
	switch.global_position = player.global_position + Vector3(4, 0, 0)
	await tree.physics_frame
	assert_eq((switch.get_node(^"Hurtbox") as Area3D).collision_layer, 0, "las demás placas no reciben golpes")
	switch.free()
