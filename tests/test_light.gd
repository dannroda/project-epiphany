extends "res://tests/test_case.gd"

const LEVEL := "res://levels/test.tscn"
const MIRROR := preload("res://src/world/light/light_mirror.tscn")


func _setup(shield: StringName) -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	state.reset()
	if shield != &"shield_wood":
		state.give(Items.get_item(shield))
		state.equip(Items.get_item(shield))
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	for i in 3:
		await tree.physics_frame
	for enemy in tree.get_nodes_in_group(&"enemies"):
		enemy.free()
	var beam: LightBeam = tree.current_scene.get_node(^"LightSource/Beam")
	var receiver: LightReceiver = tree.current_scene.get_node(^"LightReceiver")
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	player.global_position = Vector3(0, 0.25, 0)
	return [tree, state, player, beam, receiver]


func _frames(tree: SceneTree, count: int) -> void:
	for i in count:
		await tree.physics_frame


func test_beam_lights_crystal_directly() -> void:
	var setup: Array = await _setup(&"shield_wood")
	var tree: SceneTree = setup[0]
	var receiver: LightReceiver = setup[4]
	await _frames(tree, 3)
	assert_eq(receiver.lit, false, "fuera del haz, apagado")
	var events: Array = []
	receiver.activated.connect(func() -> void: events.append("on"))
	receiver.deactivated.connect(func() -> void: events.append("off"))
	receiver.global_position = Vector3(3, 0.25, -15.5)
	await _frames(tree, 4)
	assert_eq(receiver.lit, true, "en el haz, encendido")
	receiver.global_position = Vector3(6, 0.25, -12)
	await _frames(tree, 4)
	assert_eq(receiver.lit, false)
	assert_eq(events, ["on", "off"], "activated mientras recibe luz, deactivated al perderla")
	setup[1].reset()


## El haz llega desde el este (viaja hacia -X); mirando a 45° entre la fuente y el sur, el espejo lo manda al sur.
func _block_and_aim_south(tree: SceneTree, player: PlayerCharacter) -> void:
	player.global_position = Vector3(6, 0.25, -15.5)
	var facing := Vector3(1, 0, 1).normalized()
	player.model.look_at(player.model.global_position - facing, Vector3.UP)
	hold_block(player, true)
	use_gamepad()
	await _frames(tree, 6)


func _release_stick() -> void:
	pass


func test_mirror_shield_redirects_beam_to_crystal() -> void:
	var setup: Array = await _setup(&"shield_mirror")
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[2]
	var beam: LightBeam = setup[3]
	var receiver: LightReceiver = setup[4]
	await _block_and_aim_south(tree, player)
	_release_stick()
	assert_eq(beam.segments.size(), 2, "el haz rebota en el escudo")
	assert_eq(receiver.lit, true, "y llega al cristal")
	setup[1].reset()


func test_wood_shield_cuts_beam() -> void:
	var setup: Array = await _setup(&"shield_wood")
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[2]
	var beam: LightBeam = setup[3]
	var receiver: LightReceiver = setup[4]
	await _block_and_aim_south(tree, player)
	_release_stick()
	assert_eq(beam.segments.size(), 1, "el haz se corta en el escudo de madera")
	assert_true(beam.segments[0][1].distance_to(player.global_position + Vector3.UP * 1.2) < 1.0, "termina en el player")
	assert_eq(receiver.lit, false)
	setup[1].reset()


func test_fixed_mirror_bounces_beam() -> void:
	var setup: Array = await _setup(&"shield_wood")
	var tree: SceneTree = setup[0]
	var beam: LightBeam = setup[3]
	var receiver: LightReceiver = setup[4]
	var mirror: Node3D = MIRROR.instantiate()
	tree.current_scene.add_child(mirror)
	mirror.global_transform = Transform3D(Basis(Vector3.UP, deg_to_rad(45)), Vector3(9, 0.25, -15.5))
	receiver.global_position = Vector3(9, 0.25, -11)
	await _frames(tree, 4)
	assert_eq(beam.segments.size(), 2, "rebota en el espejo")
	assert_eq(receiver.lit, true, "el espejo a 45° lo manda al cristal")
	setup[1].reset()


func test_latched_receiver_stays_lit() -> void:
	var setup: Array = await _setup(&"shield_wood")
	var tree: SceneTree = setup[0]
	var receiver: LightReceiver = setup[4]
	receiver.latch = true
	receiver.global_position = Vector3(3, 0.25, -15.5)
	await _frames(tree, 4)
	receiver.global_position = Vector3(6, 0.25, -12)
	await _frames(tree, 4)
	assert_eq(receiver.lit, true, "con latch queda encendido")
	setup[1].reset()


func test_right_stick_turns_player_while_catching_light() -> void:
	var setup: Array = await _setup(&"shield_mirror")
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[2]
	var beam: LightBeam = setup[3]
	await _block_and_aim_south(tree, player)
	assert_eq(player.is_catching_light(), true, "el escudo recibe el haz")
	var start := player.global_position
	var before := player.model.global_basis.z
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_RIGHT_X
	stick.axis_value = 1.0
	Input.parse_input_event(stick)
	await _frames(tree, 15)
	stick.axis_value = 0.0
	Input.parse_input_event(stick)
	await _frames(tree, 1)
	assert_true(player.global_position.distance_to(start) < 0.05, "el stick derecho no lo mueve")
	assert_true(rad_to_deg(before.angle_to(player.model.global_basis.z)) > 5.0, "lo gira")
	var out: Vector3 = beam.segments[1][1] - beam.segments[1][0]
	assert_true(rad_to_deg(out.normalized().angle_to(Vector3.BACK)) > 5.0, "y el reflejo se mueve con él")

	var facing := player.model.global_basis.z
	var walk := InputEventJoypadMotion.new()
	walk.axis = JOY_AXIS_LEFT_X
	walk.axis_value = 1.0
	Input.parse_input_event(walk)
	await _frames(tree, 20)
	walk.axis_value = 0.0
	Input.parse_input_event(walk)
	await _frames(tree, 1)
	assert_true(player.global_position.distance_to(start) > 0.1, "el stick izquierdo lo mueve")
	assert_true(rad_to_deg(facing.angle_to(player.model.global_basis.z)) < 2.0, "sin cambiar hacia dónde mira el escudo mientras sigue en el haz")
	_release_stick()
	setup[1].reset()
