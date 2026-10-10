extends "res://tests/test_case.gd"
## El jefe (M9): piezas sueltas que mueve el código.

const SCENE := preload("res://src/entities/boss/boss.tscn")


func _spawn() -> Boss:
	var tree := Engine.get_main_loop() as SceneTree
	var boss := SCENE.instantiate() as Boss
	tree.root.add_child(boss)
	return boss


func test_pieces_and_sockets() -> void:
	var boss := _spawn()
	for path in ["Body/Mesh", "%Eye", "%OrbMuzzle", "%UpperLid", "%LowerLid", "%HandAnchorLeft", "%HandAnchorRight", "%HandRestLeft", "%HandRestRight"]:
		assert_true(boss.get_node_or_null(path) != null, "tiene %s" % path)
	assert_true(boss.orb_muzzle.get_parent() == boss.eye, "los orbes salen del ojo y giran con él")
	assert_true(boss.hand_left.get_parent() == boss and boss.hand_right.get_parent() == boss, "las manos flotan sueltas")
	assert_true(boss.hand_rest(boss.hand_left).global_position.distance_to(boss.hand_left.global_position) < 0.01, "la mano izquierda arranca en su reposo")
	assert_true(boss.hand_left.global_position.x > 0.0, "la izquierda del jefe es +X (mira a la cámara)")
	boss.free()


func test_hands_show_one_pose() -> void:
	var boss := _spawn()
	for pose in [BossHand.Pose.OPEN, BossHand.Pose.FIST, BossHand.Pose.CLAW]:
		boss.hand_right.pose = pose
		var shown := boss.hand_right.get_children().filter(func(mesh: Node3D) -> bool: return mesh.visible)
		assert_eq(shown.size(), 1, "una sola malla por pose")
	assert_eq(boss.hand_right.get_node(^"Claw").visible, true)
	boss.free()


func test_eye_opens_and_aims() -> void:
	var boss := _spawn()
	assert_eq(boss.get_node(^"%UpperLid").rotation.x, 0.0, "arranca cerrado")
	boss.eye_open = 1.0
	assert_true(boss.get_node(^"%UpperLid").rotation.x < -1.0 and boss.get_node(^"%LowerLid").rotation.x > 1.0, "los párpados se abren hacia arriba y hacia abajo")
	var target := boss.eye.global_position + Vector3(3.0, -4.0, 6.0)
	boss.look_at_point(target)
	var aim := (boss.orb_muzzle.global_position - boss.eye.global_position).normalized()
	assert_true(aim.dot((target - boss.eye.global_position).normalized()) > 0.99, "la salida de orbes apunta al blanco")
	boss.free()


func test_boss_fits_its_room() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.get_node(^"GameState").reset()
	tree.change_scene_to_file("res://levels/temple.tscn")
	await tree.scene_changed
	var level := tree.current_scene
	var boss := level.get_node(^"Boss") as Boss
	var bounds := (level.get_node(^"Jefe") as Room).bounds()
	for mesh: MeshInstance3D in boss.find_children("*", "MeshInstance3D", true, false):
		var box := mesh.global_transform * mesh.get_aabb()
		assert_true(bounds.grow(0.01).encloses(Rect2(box.position.x, box.position.z, box.size.x, box.size.z)), "%s dentro de la sala" % mesh.get_path())
	tree.root.get_node(^"GameState").reset()
