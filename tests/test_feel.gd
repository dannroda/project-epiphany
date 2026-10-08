extends "res://tests/test_case.gd"

const LEVEL := "res://levels/test.tscn"


func test_hit_stop_freezes_and_restores() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var node := Node.new()
	tree.root.add_child(node)
	var feel: Node = tree.root.get_node(^"Feel")
	feel.hit_stop([node, null], 0.05)
	await tree.process_frame
	assert_eq(node.process_mode, Node.PROCESS_MODE_DISABLED, "congelado")
	await tree.create_timer(0.12).timeout
	assert_eq(node.process_mode, Node.PROCESS_MODE_INHERIT, "restaurado")
	assert_eq(node.has_meta(&"hit_stop"), false)
	node.free()


func test_camera_trauma_decays_and_flash_is_attached() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.get_node(^"GameState").reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	await tree.process_frame
	var camera := tree.root.get_viewport().get_camera_3d() as TopDownCamera
	camera.add_trauma(0.8)
	assert_true(camera.trauma > 0.7)
	await tree.create_timer(0.8).timeout
	assert_eq(camera.trauma, 0.0, "la sacudida decae sola")
	assert_eq(camera.h_offset, 0.0)
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	var meshes := player.get_node(^"ModelController/Visuals").find_children("*", "MeshInstance3D", true, false)
	assert_true(not meshes.is_empty())
	for mesh: MeshInstance3D in meshes:
		assert_true(mesh.material_overlay != null, mesh.name)
