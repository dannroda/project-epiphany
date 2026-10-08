extends "res://tests/test_case.gd"

const LEVEL := "res://levels/test_targeting.tscn"


func _load() -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.get_node(^"GameState").reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	for enemy: Enemy in tree.get_nodes_in_group(&"enemies"):
		enemy.bt_player.active = false
	for i in 10:
		await tree.physics_frame
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	return [tree, player, tree.root.get_viewport().get_camera_3d() as TopDownCamera]


func _on_screen(camera: Camera3D, point: Vector3) -> bool:
	return not camera.is_position_behind(point) and camera.get_viewport().get_visible_rect().has_point(camera.unproject_position(point))


func test_far_lock_keeps_both_on_screen() -> void:
	var setup: Array = await _load()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var camera: TopDownCamera = setup[2]
	var far := tree.current_scene.get_node(^"Middle") as Enemy
	far.global_position = player.global_position + Vector3(0, 0, -10)
	await tree.physics_frame
	player.targeting.set_target(far)
	for i in 120:
		await tree.physics_frame
	assert_true((camera.focus - player.global_position).length() <= camera.max_lock_offset + 0.01, "el foco no se aleja de más")
	assert_true(_on_screen(camera, player.global_position + Vector3.UP), "el player en cuadro")
	assert_true(_on_screen(camera, far.global_position + Vector3.UP), "el objetivo en cuadro")
	player.targeting.clear()


func test_aim_look_ahead_eases_in_and_out() -> void:
	var setup: Array = await _load()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var camera: TopDownCamera = setup[2]
	player.model.rotation = Vector3.ZERO
	player.aim.aiming = true
	await tree.physics_frame
	var first := (camera.focus - player.global_position).length()
	assert_true(first < camera.aim_look_ahead * 0.5, "no salta de golpe")
	for i in 120:
		await tree.physics_frame
	var ahead := camera.focus - player.global_position
	assert_true(ahead.length() > camera.aim_look_ahead * 0.9, "se adelanta: %s" % ahead)
	assert_true(ahead.normalized().dot(player.aim.get_direction()) > 0.95, "hacia donde apunta")
	player.aim.aiming = false
	for i in 120:
		await tree.physics_frame
	assert_true((camera.focus - player.global_position).length() < 0.1, "vuelve al player")
