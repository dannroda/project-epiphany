extends "res://tests/test_case.gd"
## El overworld activo por zonas (15.13): lejos de todos los players los enemigos duermen y las hojas no caen.

const LEVEL := "res://levels/overworld.tscn"
const PAD_1 := 0
const PAD_2 := 1
const START := Vector3(-63, 0.5, 15)
const BANADO := Vector3(80, 0.5, 38)
const FAR := 60.0


func _overworld() -> SceneTree:
	var tree := Engine.get_main_loop() as SceneTree
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	for i in 4:
		await tree.physics_frame
	return tree


func _put(player: Node3D, at: Vector3) -> void:
	player.global_position = at
	for i in 3:
		await player.get_tree().physics_frame


func _leaves(level: Node, near: Vector3, awake: bool) -> Array:
	return level.get_node(^"Decor").find_children("*", "GPUParticles3D", true, false).filter(func(leaves: GPUParticles3D) -> bool:
		var gap := Vector2(leaves.global_position.x - near.x, leaves.global_position.z - near.z).length()
		return (gap < 12.0) if awake else (gap > FAR + 40.0))


func test_far_enemies_sleep_and_wake_when_a_player_comes() -> void:
	var tree := await _overworld()
	var level := tree.current_scene
	var players: Node = tree.root.get_node(^"Players")
	await _put(players.lead(), START)
	var devoto := level.get_node(^"DevotoBanado1") as Node3D
	assert_true(not devoto.can_process(), "el Devoto del Bañado duerme con el player en el arranque")
	var still := devoto.global_position
	for i in 10:
		await tree.physics_frame
	assert_eq(devoto.global_position, still, "dormido no se mueve")
	await _put(players.lead(), BANADO)
	assert_true(devoto.can_process(), "despierta cuando llega el player")
	assert_true(level.get_node(^"DevotoCardonal1").can_process(), "el Cardonal de al lado también")


func test_far_leaves_stop_falling() -> void:
	var tree := await _overworld()
	var level := tree.current_scene
	var players: Node = tree.root.get_node(^"Players")
	await _put(players.lead(), START)
	var near := _leaves(level, START, true)
	var far := _leaves(level, START, false)
	assert_true(not near.is_empty() and not far.is_empty(), "hay árboles cerca y lejos del arranque")
	assert_true(near.all(func(leaves: GPUParticles3D) -> bool: return leaves.emitting), "cerca caen hojas")
	assert_true(far.all(func(leaves: GPUParticles3D) -> bool: return not leaves.emitting), "lejos no")
	await _put(players.lead(), BANADO)
	assert_true(_leaves(level, BANADO, true).all(func(leaves: GPUParticles3D) -> bool: return leaves.emitting), "al llegar al Bañado caen ahí")
	assert_true(_leaves(level, BANADO, false).all(func(leaves: GPUParticles3D) -> bool: return not leaves.emitting), "y paran en el arranque")


func test_each_player_keeps_its_own_zone_awake() -> void:
	var tree := await _overworld()
	var level := tree.current_scene
	var players: Node = tree.root.get_node(^"Players")
	players.lead_pad = PAD_1
	var second: PlayerCharacter = players.join(PAD_2)
	for i in 3:
		await tree.physics_frame
	await _put(players.lead(), START)
	await _put(second, BANADO)
	assert_true(level.get_node(^"DevotoBanado1").can_process(), "el segundo player despierta el Bañado")
	for slot in players.guests.keys():
		players.leave(slot)
	players.lead_pad = -1
	for i in 3:
		await tree.physics_frame
	assert_true(not level.get_node(^"DevotoBanado1").can_process(), "cuando se va, vuelve a dormir")
