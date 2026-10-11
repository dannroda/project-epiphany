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


func test_stencil_lights_draw_before_the_player_silhouette() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var torch: Node3D = load("res://src/world/wall_torch.tscn").instantiate()
	var other: StencilLight = load("res://src/feel/stencil_light/stencil_light.tscn").instantiate()
	tree.root.add_child(torch)
	tree.root.add_child(other)
	var glow := torch.get_node(^"Glow") as StencilLight
	assert_true(glow != null, "la antorcha tiene su luz")
	var priorities := []
	for light in [glow, other]:
		var pass_material: Material = light.volume.material_override
		while pass_material:
			assert_true(pass_material.render_priority < 0, "antes del destello y la silueta (prioridades 0 y 1)")
			priorities.append(pass_material.render_priority)
			pass_material = pass_material.next_pass
	assert_eq(priorities.size(), 6, "tres pasadas por luz")
	assert_true(priorities[2] < priorities[3] or priorities[5] < priorities[0], "cada luz tiene sus prioridades")
	torch.free()
	other.free()


func test_bursts_reuse_one_low_poly_template() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.get_node(^"GameState").reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	var feel: Node = tree.root.get_node(^"Feel")
	for kind in [&"sparks", &"sparks", &"dust", &"explosion"]:
		feel.burst(kind, Vector3.UP, Vector3.UP)
	var bursts := tree.current_scene.find_children("*", "CPUParticles3D", false, false)
	assert_eq(bursts.size(), 4)
	assert_true(bursts[0].mesh == bursts[1].mesh, "la misma ráfaga comparte la malla")
	assert_eq((bursts[2].mesh as SphereMesh).radial_segments, 4, "octaedros, no esferas")
	assert_true(bursts[0].scale_amount_curve != null, "se achican al morir")
	var rings := tree.current_scene.find_children("*", "MeshInstance3D", false, false).filter(func(n: Node) -> bool: return n.mesh is TorusMesh)
	assert_eq(rings.size(), 1, "la explosión abre un anillo")
