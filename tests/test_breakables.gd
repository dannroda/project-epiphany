extends "res://tests/test_case.gd"

const LEVEL := "res://levels/test.tscn"


func _load(tree: SceneTree) -> void:
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	for i in 3:
		await tree.physics_frame
	for enemy in tree.get_nodes_in_group(&"enemies"):
		enemy.queue_free()


func _swing_at(tree: SceneTree, player: PlayerCharacter, target: Vector3, distance := 1.0) -> void:
	var from := target + Vector3(0, 0, distance)
	player.global_position = from
	player.model.look_at(player.model.global_position + Vector3.BACK, Vector3.UP)
	for i in 3:
		await tree.physics_frame
	var event := InputEventAction.new()
	event.action = &"attack"
	event.pressed = true
	Input.parse_input_event(event)
	var release := InputEventAction.new()
	release.action = &"attack"
	Input.parse_input_event(release)
	await tree.create_timer(0.9).timeout


func test_sword_breaks_pot_and_it_returns_on_reload() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	state.reset()
	await _load(tree)
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	var pot: Breakable = tree.current_scene.get_node(^"Pot1")
	var always := DropTable.new()
	var heart := DropEntry.new()
	heart.heal = 4
	always.entries.assign([heart])
	pot.drops = always
	for other in [^"Pot2", ^"Pot3"]:
		tree.current_scene.get_node(other).drops = null
	var spawned: Array = []
	var watch := func(node: Node) -> void:
		if node is Pickup:
			spawned.append(node)
	tree.node_added.connect(watch)
	await _swing_at(tree, player, pot.global_position)
	tree.node_added.disconnect(watch)
	assert_eq(is_instance_valid(pot), false, "la espada rompe la vasija")
	assert_eq(spawned.size(), 1, "suelta un corazón")
	await _load(tree)
	assert_true(tree.current_scene.has_node(^"Pot1"), "vuelve al recargar la escena")
	state.reset()


func test_sword_cuts_grass() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	state.reset()
	await _load(tree)
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	var patch: Node3D = tree.current_scene.get_node(^"GrassPatch")
	assert_eq(patch.get_child_count(), 50, "campo de 50 matas")
	var first := patch.get_child(patch.columns * (patch.rows - 1) + 4) as Node3D
	await _swing_at(tree, player, first.global_position)
	assert_true(patch.get_children().any(func(grass: Breakable) -> bool: return grass.broken), "la espada corta pasto")
	await tree.create_timer(0.5).timeout
	assert_true(first.get_node(^"Stump").visible and not first.has_node(^"Model"), "salta la mata y queda el ichu cortado")
	state.reset()


func test_overworld_plants_are_cut_like_grass() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	state.reset()
	tree.change_scene_to_file("res://levels/overworld.tscn")
	await tree.scene_changed
	for i in 3:
		await tree.physics_frame
	for enemy in tree.get_nodes_in_group(&"enemies"):
		enemy.queue_free()
	var level := tree.current_scene
	var grid: GridMap = level.get_node(^"GridMap")
	var plants := level.get_node(^"Decor/Plantas").get_children().filter(func(node: Node) -> bool: return node is Breakable)
	assert_true(plants.size() > 100, "las plantas del piso jugable se cortan (%d)" % plants.size())
	for cell in grid.get_used_cells():
		var cell_name := grid.mesh_library.get_item_name(grid.get_cell_item(cell))
		if cell_name in ["Árbol", "Queñoa chica", "Cardón", "Cardón brazos"]:
			var at := grid.map_to_local(cell) + grid.position
			assert_true(plants.any(func(plant: Breakable) -> bool: return plant.global_position.distance_to(at) < 0.1), "%s en %s es cortable" % [cell_name, at])
			assert_eq(grid.mesh_library.get_item_shapes(grid.get_cell_item(cell)).size(), 0, "y la celda no choca ni se dibuja: la planta lo hace")
	var cactus: Breakable = plants.filter(func(plant: Breakable) -> bool: return plant.global_position.distance_to(Vector3(-20, 0, 2)) < 0.1).front()
	var tree_plant: Breakable = plants.filter(func(plant: Breakable) -> bool: return plant.has_node(^"Stump") and plant.get_node(^"Body") != null).front()
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	await _swing_at(tree, player, cactus.global_position, 1.3)
	assert_true(cactus.broken, "la espada corta el cardón de la arboleda")
	await tree.create_timer(1.5).timeout
	assert_eq(is_instance_valid(cactus), false, "cae, se hunde y se va")
	var model := tree_plant.get_node(^"Model") as Node3D
	tree_plant.smash(tree_plant.global_position + Vector3(0, 0, 2))
	assert_eq(tree_plant.get_node(^"Body").process_mode, Node.PROCESS_MODE_DISABLED, "el paso se abre en el acto")
	await tree.create_timer(0.6).timeout
	var top := model.global_basis.y
	assert_true(top.z < -0.8, "el árbol cae para el lado contrario al golpe (%s)" % top)
	await tree.create_timer(1.0).timeout
	assert_true(is_instance_valid(tree_plant) and tree_plant.get_node(^"Stump").visible and not is_instance_valid(model), "y queda el tocón")
	state.reset()


func test_the_sandals_crash_shakes_trees_and_cracked_walls() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	state.reset()
	tree.change_scene_to_file("res://levels/overworld.tscn")
	await tree.scene_changed
	for i in 3:
		await tree.physics_frame
	var level := tree.current_scene
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	var plants := level.get_node(^"Decor/Plantas").get_children().filter(func(node: Node) -> bool: return node is Breakable)
	var tree_plant: Breakable = plants.filter(func(plant: Breakable) -> bool: return plant.break_style == Breakable.Break.FELL).front()
	var model := tree_plant.get_node(^"Model") as Node3D
	var rest := model.position
	tree_plant.hurtbox.receive(DamageInfo.make(1, 6.0, player, &"dash"))
	await tree.create_timer(0.6).timeout
	assert_eq(tree_plant.broken, false, "el choque sacude el árbol sin voltearlo")
	assert_true(model.position.is_equal_approx(rest), "y vuelve a su lugar")
	var wall := level.get_node(^"ShrineCrackedWall") as CrackedWall
	wall.hurtbox.receive(DamageInfo.make(1, 6.0, player, &"dash"))
	await tree.create_timer(0.4).timeout
	assert_eq(wall.is_broken, false, "el muro agrietado se sacude pero solo lo rompe una bomba")
	state.reset()
