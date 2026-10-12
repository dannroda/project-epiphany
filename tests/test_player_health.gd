extends "res://tests/test_case.gd"

const LEVEL := "res://levels/test.tscn"
const SLOT := 96


func _enter() -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	await tree.physics_frame
	return [tree, tree.get_first_node_in_group(&"player") as PlayerCharacter]


func test_health_survives_a_scene_change() -> void:
	var state: Node = (Engine.get_main_loop() as SceneTree).root.get_node(^"GameState")
	state.reset()
	var setup: Array = await _enter()
	var player: PlayerCharacter = setup[1]
	player.health.invulnerability_time = 0.0
	player.health.damage(5)
	var left := player.health.current
	assert_true(left < state.max_health, "le sacaron vida")
	setup = await _enter()
	player = setup[1]
	assert_eq(player.health.current, left, "en la escena nueva tiene la misma vida")
	state.reset()


func test_health_is_saved_and_loaded() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	var saves: Node = tree.root.get_node(^"SaveManager")
	state.reset()
	var setup: Array = await _enter()
	var player: PlayerCharacter = setup[1]
	player.health.invulnerability_time = 0.0
	player.health.damage(5)
	var left := player.health.current
	assert_eq(saves.save_game(SLOT), OK)
	player.health.reset(state.max_health)
	assert_eq(await saves.load_game(SLOT), OK)
	assert_eq(player.health.current, left, "cargar la partida devuelve la vida que tenía")
	for suffix in ["", ".bak"]:
		DirAccess.remove_absolute(saves.slot_path(SLOT) + suffix)
	state.reset()


func test_fallen_player_comes_back_full_and_containers_fill() -> void:
	var state: Node = (Engine.get_main_loop() as SceneTree).root.get_node(^"GameState")
	state.reset()
	state.set_health_of(0, 0)
	var setup: Array = await _enter()
	var player: PlayerCharacter = setup[1]
	assert_eq(player.health.current, state.max_health, "caído (0) vuelve con la vida llena")
	player.health.invulnerability_time = 0.0
	player.health.damage(5)
	state.give(Items.get_item(&"heart_container"))
	assert_eq(player.health.current, state.max_health, "un contenedor de corazón llena la vida")
	assert_eq(state.health_of(0), state.max_health)
	state.reset()
