extends "res://tests/test_case.gd"
## La pieza 16 (11.124): en el nicho del Mirador, detrás de una reja que baja la placa de golpe de la cornisa. Solo el
## martillazo la aprieta (ni la espada ni el golpe en picada); el gancho no trae la pieza a través de la reja.

const LEVEL := "res://levels/overworld.tscn"
const PLUNGE_WAVE := preload("res://src/combat/plunge_wave.tscn")
const LEVELS := ["overworld", "grotto_cave", "shrine_cave", "bush_cave", "bomb_cave", "spring_cave", "huaca", "reflejos",
	"chullpa", "quenoa", "totora", "cumbre", "templo"]

var tree: SceneTree
var state: Node
var player: PlayerCharacter


func _start() -> void:
	tree = Engine.get_main_loop() as SceneTree
	state = tree.root.get_node(^"GameState")
	state.reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	for enemy in tree.get_nodes_in_group(&"enemies"):
		enemy.free()
	player = tree.get_first_node_in_group(&"player") as PlayerCharacter
	use_gamepad()
	state.give(Items.get_item(&"hammer"))
	state.give(Items.get_item(&"hookshot"))
	state.assign_button(0, &"hammer")
	state.assign_button(1, &"hookshot")


func _idle() -> bool:
	return player.movement_state.get_active_state().name == &"Idle"


func _place(at: Vector3, facing: Vector3) -> void:
	var still := 0
	for i in 300:
		player.global_position = at
		player.velocity = Vector3.ZERO
		player.model.look_at(player.model.global_position - facing, Vector3.UP)
		await tree.physics_frame
		still = still + 1 if _idle() else 0
		if still >= 10:
			break


func _press(action: StringName, seconds := 1.4) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
		await tree.physics_frame
	await tree.create_timer(seconds).timeout


func _until(condition: Callable, seconds := 5.0) -> bool:
	var until := Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < until:
		if condition.call():
			return true
		await tree.physics_frame
	return false


func test_the_hammer_plate_lowers_the_gate_on_the_mirador_piece() -> void:
	await _start()
	var plate := tree.current_scene.get_node(^"MiradorStrikePlate") as FloorSwitch
	var gate := tree.current_scene.get_node(^"MiradorGate") as Gate
	var piece := tree.current_scene.get_node(^"HeartPieceMirador") as HeartPiece
	assert_eq(plate.mode, FloorSwitch.Mode.STRIKE, "la placa es de golpe")
	assert_true(piece.visible, "la pieza se ve detrás de la reja")
	await _place(gate.global_position + Vector3(-3, 0, 0), Vector3.RIGHT)
	await _press(&"item_2")
	assert_true(not piece.taken, "el gancho no la trae a través de la reja")
	await _place(plate.global_position + Vector3(0, 0, 1.2), Vector3.FORWARD)
	await _press(&"attack")
	assert_true(not plate.active and not gate.is_open, "la espada no aprieta la placa")
	var wave := PLUNGE_WAVE.instantiate() as Hitbox
	wave.team = player.hurtbox.team
	wave.damage_factory = player._make_damage
	tree.current_scene.add_child(wave)
	wave.global_position = plate.global_position
	for i in 6:
		await tree.physics_frame
	assert_true(not plate.active and not gate.is_open, "ni la onda del golpe en picada")
	await _press(&"item_1")
	assert_true(plate.active, "el martillazo sí")
	assert_true(await _until(func() -> bool: return gate.is_open, 6.0), "y baja la reja del nicho")
	assert_eq(state.get_flag(&"ow_mirador_strike"), true)
	await _place(piece.global_position + Vector3(-1.5, 0, 0), Vector3.RIGHT)
	for i in 120:
		player.global_position = piece.global_position
		await tree.physics_frame
		if piece.taken:
			break
	assert_true(piece.taken, "la pieza se toma desde el nicho")
	assert_eq(state.get_flag(&"ow_heart_piece_mirador"), true)
	assert_eq(state.heart_pieces(), 1)
	var stack: Node = tree.root.get_node(^"MenuStack")
	for i in 120:
		await tree.process_frame
		if stack.top() != null:
			break
	if stack.top() != null:
		stack.pop()
	state.reset()


func test_sixteen_heart_pieces_make_four_hearts() -> void:
	var flags := {}
	for level in LEVELS:
		var scene: Node = (load("res://levels/%s.tscn" % level) as PackedScene).instantiate()
		for node in scene.find_children("*", "", true, false):
			if node is HeartPiece:
				flags[node.flag] = level
			elif node is Chest and node.item and node.item.id == &"heart_piece":
				flags[node.flag] = level
		scene.free()
	assert_eq(flags.size(), 16, "16 piezas: %s" % flags.keys())
	assert_eq(flags.size() % 4, 0, "completan contenedores enteros")
	assert_eq(flags.get(&"ow_heart_piece_mirador"), "overworld", "la del Mirador está en el overworld")
