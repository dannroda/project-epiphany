extends "res://tests/test_case.gd"
## La prueba de 7.8: desde `start`, las bombas de la cueva, el atajo del santuario y, con el escudo espejo de D4, el sello del
## templo: entrar y volver a salir.

const OVERWORLD := "res://levels/overworld.tscn"
const DUNGEON := "res://levels/templo.tscn"
const BOMB_CAVE := "res://levels/bomb_cave.tscn"
const SHRINE := "res://levels/shrine_cave.tscn"
const SLOT := 9

var tree: SceneTree
var player: PlayerCharacter


func _walk(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	event.strength = 1.0
	Input.parse_input_event(event)


func _walk_until(action: StringName, done: Callable) -> bool:
	_walk(action, true)
	var until := Time.get_ticks_msec() + 12000
	while Time.get_ticks_msec() < until and not done.call():
		await tree.physics_frame
	_walk(action, false)
	await tree.physics_frame
	return done.call()


func _walk_into(action: StringName, scene_path: String) -> bool:
	var saves: Node = tree.root.get_node(^"SaveManager")
	_walk(action, true)
	var until := Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < until and not tree.root.get_node(^"SceneFlow").traveling:
		await tree.physics_frame
	_walk(action, false)
	while Time.get_ticks_msec() < until and tree.root.get_node(^"SceneFlow").traveling:
		await tree.process_frame
	_clear_enemies()
	player = tree.get_first_node_in_group(&"player") as PlayerCharacter
	await tree.physics_frame
	return tree.current_scene.scene_file_path == scene_path


func _press(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	var release := InputEventAction.new()
	release.action = action
	Input.parse_input_event(release)
	for i in 3:
		await tree.physics_frame


func _face(direction: Vector3) -> void:
	player.model.look_at(player.model.global_position - direction.normalized(), Vector3.UP)


func _place(at: Vector3, facing: Vector3) -> void:
	player.global_position = at
	player.velocity = Vector3.ZERO
	_face(facing)
	await tree.physics_frame


func _open_chest(node: NodePath) -> void:
	var stack: Node = tree.root.get_node(^"MenuStack")
	(tree.current_scene.get_node(node) as Chest).interactable.interact(player)
	await tree.create_timer(1.0).timeout
	while stack.is_open():
		stack.pop()
		await tree.process_frame
		await tree.process_frame
	await tree.create_timer(1.2).timeout


func _bomb_wall(node: NodePath, stand: Vector3, facing: Vector3, retreat: Vector3) -> bool:
	var wall := tree.current_scene.get_node(node) as CrackedWall
	await _place(wall.global_position + stand, facing)
	await _press(&"item_1")
	await tree.create_timer(1.0).timeout
	player.global_position = retreat
	await tree.create_timer(2.6).timeout
	return wall.is_broken


func _reflect(at: Vector3, facing: Vector3) -> void:
	await _place(at, facing)
	hold_block(player, true)
	use_gamepad()
	for i in 8:
		await tree.physics_frame
	hold_block(player, false)
	await tree.create_timer(1.0).timeout


func _clear_enemies() -> void:
	for enemy in tree.get_nodes_in_group(&"enemies"):
		enemy.free()


func test_play_start_into_the_temple_and_back() -> void:
	tree = Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	var saves: Node = tree.root.get_node(^"SaveManager")
	state.reset()
	saves.current_slot = SLOT
	assert_eq(await saves.load_scenario("start"), OK)
	assert_eq(tree.current_scene.scene_file_path, OVERWORLD, "start arranca en el overworld")
	_clear_enemies()
	player = tree.get_first_node_in_group(&"player") as PlayerCharacter
	player.health.invulnerability_time = 0.0
	await tree.create_timer(0.3).timeout
	var at := func(axis: int, sign_: float, value: float) -> Callable:
		return func() -> bool: return (player.global_position[axis] - value) * sign_ >= 0.0

	assert_true(await _walk_until(&"move_forward", at.call(2, -1.0, -4.0)), "del claro a la pradera")
	await _place(Vector3(-66, 0, -16), Vector3.LEFT)
	assert_true(await _walk_into(&"move_left", BOMB_CAVE), "entra a la cueva de las bombas")
	await _place(Vector3(-4, 0, -3.6), Vector3.FORWARD)
	await _open_chest(^"CaveChest")
	assert_eq(state.inventory.has(&"bomb_bag"), true, "bombas")
	await _place(Vector3(12, 0, 0), Vector3.RIGHT)
	assert_true(await _walk_into(&"move_right", OVERWORLD), "sale de la cueva")

	var wall := tree.current_scene.get_node(^"ShrineCrackedWall") as Node3D
	assert_true(await _bomb_wall(^"ShrineCrackedWall", Vector3(0, 0, 2.1), Vector3.FORWARD, wall.global_position + Vector3(0, 0, 6)), "muro del santuario")
	await _place(wall.global_position + Vector3(0, 0, 2.0), Vector3.FORWARD)
	assert_true(await _walk_into(&"move_forward", SHRINE), "entra al santuario caminando")
	await _place(Vector3(0, 0, 6), Vector3.BACK)
	assert_true(await _walk_into(&"move_backward", OVERWORLD), "sale del santuario por donde entró")

	state.give(Items.get_item(&"shield_mirror"))
	state.equip(Items.get_item(&"shield_mirror"))
	await _reflect(Vector3(-34, 5.2, -28), Vector3(-1, 0, -1))
	assert_eq((tree.current_scene.get_node(^"TempleSeal") as TempleSeal).is_open, true, "con el escudo espejo de D4, sello abierto")
	await tree.create_timer(1.0).timeout

	await _place(Vector3(-42, 5.2, -33), Vector3.FORWARD)
	assert_true(await _walk_into(&"move_forward", DUNGEON), "entra al templo")
	assert_true(await _walk_into(&"move_backward", OVERWORLD), "y vuelve a salir")
	assert_eq((tree.current_scene.get_node(^"TempleSeal") as TempleSeal).is_open, true, "el sello sigue abierto")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saves.slot_path(SLOT)))
	saves.current_slot = 1
	state.reset()
