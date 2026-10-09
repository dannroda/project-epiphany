extends "res://tests/test_case.gd"

const OVERWORLD := "res://levels/overworld.tscn"
const DUNGEON := "res://levels/temple.tscn"
const SLOT := 9


func _walk(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	event.strength = 1.0
	Input.parse_input_event(event)


func _walk_into(tree: SceneTree, action: StringName, scene_path: String) -> bool:
	var saves: Node = tree.root.get_node(^"SaveManager")
	_walk(action, true)
	var until := Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < until and not saves.traveling:
		await tree.physics_frame
	_walk(action, false)
	while Time.get_ticks_msec() < until and saves.traveling:
		await tree.process_frame
	for enemy in tree.get_nodes_in_group(&"enemies"):
		enemy.free()
	await tree.physics_frame
	return tree.current_scene.scene_file_path == scene_path


func _frames(tree: SceneTree, count: int) -> void:
	for i in count:
		await tree.physics_frame


func test_reflect_the_light_into_the_seal_and_enter() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	var saves: Node = tree.root.get_node(^"SaveManager")
	state.reset()
	saves.current_slot = SLOT
	tree.change_scene_to_file(OVERWORLD)
	await tree.scene_changed
	assert_eq(await saves.load_scenario("pre_temple"), OK)
	for enemy in tree.get_nodes_in_group(&"enemies"):
		enemy.free()
	var level := tree.current_scene
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	var seal := level.get_node(^"TempleSeal") as TempleSeal
	var crystal := level.get_node(^"SealCrystal") as LightReceiver
	var camera := level.get_node(^"TopDownCamera") as TopDownCamera
	assert_eq(state.equipment[ItemData.Category.SHIELD], &"shield_mirror", "pre_temple trae el escudo espejo")
	assert_eq(seal.is_open, false, "el sello cierra el templo")

	player.global_position = Vector3(0, 0, -17)
	await tree.create_timer(0.3).timeout
	assert_eq(await _walk_into(tree, &"move_forward", DUNGEON), false, "con el sello cerrado no se entra")

	player.global_position = Vector3(8, 0, -11)
	player.model.look_at(player.model.global_position - Vector3(-1, 0, -1).normalized(), Vector3.UP)
	player.movement_state.blackboard.set_var("is_blocking", true)
	use_gamepad()
	player.set_guard(true)
	await _frames(tree, 8)
	assert_eq(crystal.lit, true, "el espejo fijo y el escudo llevan el haz al cristal del sello")
	player.set_guard(false)
	player.movement_state.blackboard.set_var("is_blocking", false)
	await _frames(tree, 2)
	assert_eq(seal.is_open, true, "el sello se abre")
	assert_true(camera.trauma > 0.3, "y el mundo tiembla")
	assert_eq(state.get_flag(&"ow_temple_seal_open"), true)
	await tree.create_timer(1.8).timeout

	player.global_position = Vector3(0, 0, -17)
	await tree.create_timer(0.3).timeout
	assert_true(await _walk_into(tree, &"move_forward", DUNGEON), "abierto, la entrada lleva a la mazmorra")
	assert_true(await _walk_into(tree, &"move_backward", OVERWORLD), "y se vuelve al overworld")
	assert_eq((tree.current_scene.get_node(^"TempleSeal") as TempleSeal).is_open, true, "al volver la entrada sigue abierta")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saves.slot_path(SLOT)))
	saves.current_slot = 0
	state.reset()


func test_tremors_near_the_temple() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	state.reset()
	tree.change_scene_to_file(OVERWORLD)
	await tree.scene_changed
	for enemy in tree.get_nodes_in_group(&"enemies"):
		enemy.free()
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	var tremors := tree.current_scene.get_node(^"TempleTremors") as TremorZone
	var count := [0]
	tremors.trembled.connect(func() -> void: count[0] += 1)
	await tree.create_timer(2.0).timeout
	assert_eq(count[0], 0, "lejos del templo no tiembla")
	player.global_position = Vector3(0, 0, -12)
	await tree.create_timer(2.0).timeout
	assert_eq(count[0], 1, "al acercarse, un temblor suave")
	state.reset()
