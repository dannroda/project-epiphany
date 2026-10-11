extends "res://tests/test_case.gd"
## Cueva de la vertiente: agua con cáusticas, llenar botellas con agua bendita (11.20).

const CAVE := "res://levels/spring_cave.tscn"
const BOTTLE := preload("res://assets/items/bottle/bottle.tscn")


func _setup() -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	state.reset()
	tree.change_scene_to_file(CAVE)
	await tree.scene_changed
	for i in 5:
		await tree.process_frame
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	player.health.invulnerability_time = 0.0
	return [tree, state, player, tree.current_scene.get_node(^"Spring") as Spring]


func _close_top(tree: SceneTree) -> void:
	var stack: Node = tree.root.get_node(^"MenuStack")
	await tree.create_timer(0.8).timeout
	while stack.top() != null:
		stack.pop()
		await tree.create_timer(0.3).timeout


func _press(tree: SceneTree, action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	var release := InputEventAction.new()
	release.action = action
	Input.parse_input_event(release)
	for i in 3:
		await tree.physics_frame


func test_spring_fills_the_empty_bottle_and_keeps_its_button() -> void:
	var setup: Array = await _setup()
	var tree: SceneTree = setup[0]
	var state: Node = setup[1]
	var player: PlayerCharacter = setup[2]
	var spring: Spring = setup[3]
	assert_eq(spring.interactable.prompt, "PROMPT_DRINK", "sin botella se bebe")
	state.give(Items.get_item(&"bottle_empty"))
	state.assign_button(1, &"bottle_empty")
	assert_eq(spring.interactable.prompt, "PROMPT_FILL", "con botella vacía se llena")
	spring._use(player)
	assert_true(state.inventory.has(&"holy_water") and not state.inventory.has(&"bottle_empty"), "la botella queda con agua bendita")
	assert_eq(state.item_buttons[1], &"holy_water", "en el mismo botón")
	assert_eq(spring.interactable.prompt, "PROMPT_DRINK")
	await _close_top(tree)
	state.reset()


func test_drinking_from_the_spring_heals_fully() -> void:
	var setup: Array = await _setup()
	var tree: SceneTree = setup[0]
	var state: Node = setup[1]
	var player: PlayerCharacter = setup[2]
	player.health.damage(6)
	setup[3]._use(player)
	assert_eq(player.health.current, player.health.max_health, "toda la vida")
	await _close_top(tree)
	state.reset()


func test_holy_water_wards_halves_damage_and_leaves_the_bottle() -> void:
	var setup: Array = await _setup()
	var tree: SceneTree = setup[0]
	var state: Node = setup[1]
	var player: PlayerCharacter = setup[2]
	state.give(Items.get_item(&"holy_water"))
	state.assign_button(0, &"holy_water")
	await _press(tree, &"item_1")
	await tree.create_timer(1.8).timeout
	assert_true(player.health.is_warded(), "queda bendecido")
	assert_true(player.get_node_or_null(^"Blessing") != null, "se ve el brillo")
	assert_eq(state.item_buttons[0], &"bottle_empty", "la botella vacía queda en X")
	var before := player.health.current
	player.health.damage(4)
	assert_eq(player.health.current, before - 2, "el daño entra a la mitad")
	player.health._ward_left = 0.1
	await tree.create_timer(0.3).timeout
	assert_true(not player.health.is_warded(), "se termina")
	assert_true(player.get_node_or_null(^"Blessing") == null or player.get_node(^"Blessing").is_queued_for_deletion(), "y se apaga el brillo")
	state.reset()


func test_one_bottle_shows_whatever_it_holds() -> void:
	var bottle := BOTTLE.instantiate() as BottleModel
	(Engine.get_main_loop() as SceneTree).root.add_child(bottle)
	var liquid: MeshInstance3D = bottle.get_node(^"Liquid")
	bottle.content = Items.get_item(&"bottle_empty")
	assert_true(not liquid.visible, "vacía no tiene líquido")
	for id: StringName in [&"potion", &"holy_water"]:
		var item := Items.get_item(id)
		bottle.content = item
		var material := liquid.material_override as StandardMaterial3D
		assert_true(liquid.visible and material.albedo_color.is_equal_approx(item.liquid), "%s tiñe el líquido" % id)
	assert_true(not Items.get_item(&"potion").liquid.is_equal_approx(Items.get_item(&"holy_water").liquid), "se distinguen por color")
	bottle.free()


func test_pool_reflects_the_water_on_the_walls_and_blocks_walking_in() -> void:
	var setup: Array = await _setup()
	var state: Node = setup[1]
	var pool := (setup[0] as SceneTree).current_scene.get_node(^"WaterPool") as WaterPool
	var water := pool.surface.mesh.surface_get_material(0) as ShaderMaterial
	var wall := pool.get_node(^"Caustics") as CausticsLight
	var spill := pool.get_node(^"FloorCaustics") as CausticsDecal
	assert_eq(pool.projectors().size(), 2)
	assert_true(wall.light_projector == wall.canvas.texture and wall.shadow_enabled, "la luz proyecta el agua (sin sombra 4.8-dev7 no aplica el projector)")
	assert_true(spill.texture_emission == spill.canvas.texture, "el decal también")
	for material: ShaderMaterial in [wall.canvas.material, spill.canvas.material]:
		assert_eq(material.get_shader_parameter(&"tile"), water.get_shader_parameter(&"tile"), "mismo patrón que la espuma")
	assert_true(wall.global_position.y < pool.surface.global_position.y and -wall.global_basis.z.y > 0.5, "el reflejo sube a las paredes desde abajo del agua")
	assert_true(spill.normal_fade > 0.0 and not spill.canvas.material.get_shader_parameter(&"lit_inside"), "el piso de alrededor sin encimarse con el agua ni con la pared")
	assert_true(spill.size.x > pool.size.x and spill.size.z > pool.size.y, "el decal cubre la pileta y su borde")
	assert_true((pool.block.shape as BoxShape3D).size.x >= pool.size.x, "no se puede entrar al agua")
	var fall := pool.get_parent().get_node(^"Waterfall") as Node3D
	var local := pool.to_local(fall.global_position)
	assert_true(absf(local.x) < pool.size.x / 2.0 and absf(local.z) < pool.size.y / 2.0, "la cascada cae en la pileta")
	state.reset()


func test_cave_and_overworld_portals_meet() -> void:
	var overworld: Node = (load("res://levels/overworld.tscn") as PackedScene).instantiate()
	var cave: Node = (load(CAVE) as PackedScene).instantiate()
	var door := overworld.get_node(^"SpringCaveDoor") as Portal
	var exit := cave.get_node(^"ExitPortal") as Portal
	assert_eq(door.target_scene, CAVE)
	assert_eq(exit.target_scene, "res://levels/overworld.tscn")
	var ids := func(level: Node) -> Array: return level.find_children("*", "SpawnPoint", true, false).map(func(s: SpawnPoint) -> StringName: return StringName(s.id))
	assert_true(StringName(door.target_spawn) in ids.call(cave), "la puerta llega a un spawn de la cueva")
	assert_true(StringName(exit.target_spawn) in ids.call(overworld), "la salida vuelve al claro")
	overworld.free()
	cave.free()
