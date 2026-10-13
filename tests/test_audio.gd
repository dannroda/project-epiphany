extends "res://tests/test_case.gd"


func test_buses_and_varied_samples() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	for bus in [&"Music", &"SFX", &"UI", &"Ambience"]:
		assert_true(AudioServer.get_bus_index(bus) != -1, "bus %s" % bus)
	var feel: Node = tree.root.get_node(^"Feel")
	for sound in [&"hit", &"hurt", &"block", &"break", &"deny", &"ui_move", &"ui_accept"]:
		assert_true(feel._sounds.get(sound, []).size() >= 3, "%s tiene varias muestras" % sound)
	tree.root.get_node(^"GameState").reset()
	tree.change_scene_to_file("res://levels/test.tscn")
	await tree.scene_changed
	var streams := {}
	var pitches := {}
	for i in 12:
		feel.sfx(&"hit", Vector3.ZERO)
	for child in tree.current_scene.get_children():
		if child is AudioStreamPlayer3D:
			streams[child.stream] = true
			pitches[snappedf(child.pitch_scale, 0.001)] = true
	assert_true(streams.size() > 1, "los golpes repetidos no suenan idénticos")
	assert_true(pitches.size() > 1, "y varía el tono")
	var before := feel.get_children().filter(func(node: Node) -> bool: return node is AudioStreamPlayer).size()
	feel.ui(&"ui_accept")
	var ui_players := feel.get_children().filter(func(node: Node) -> bool: return node is AudioStreamPlayer)
	assert_eq(ui_players.size(), before + 1, "sonido de interfaz")
	assert_eq((ui_players.back() as AudioStreamPlayer).bus, &"UI", "en el bus UI")


func test_music_layers_follow_the_doom() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var music: Node = tree.root.get_node(^"Music")
	var saves: Node = tree.root.get_node(^"SaveManager")
	for layer in music.LAYERS:
		var stream := (music.players[layer] as AudioStreamPlayer).stream as AudioStreamWAV
		assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD, "%s en loop" % layer)
		assert_eq((music.players[layer] as AudioStreamPlayer).bus, &"Ambience" if layer == &"murmur" else &"Music", "%s en su bus" % layer)
	await saves.load_scenario("start")
	await tree.create_timer(0.3).timeout
	var wanted: Dictionary = music.targets()
	assert_eq(wanted[&"calm"], 1.0, "overworld: calma")
	assert_eq(wanted[&"dark"], 0.0)
	await saves.load_scenario("dungeon_no_bow")
	(tree.get_first_node_in_group(&"player") as Node3D).global_position = Vector3(24, 0, 68)
	await tree.create_timer(1.5).timeout
	wanted = music.targets()
	assert_eq(wanted[&"dark"], 1.0, "templo: base oscura")
	assert_eq(wanted[&"heartbeat"], 0.0, "en el vestíbulo, sin latido")
	await saves.load_scenario("pre_boss")
	await tree.create_timer(0.5).timeout
	wanted = music.targets()
	assert_true(wanted[&"pulse"] > 0.9 and wanted[&"murmur"] > 0.9 and wanted[&"heartbeat"] > 0.9, "en la antesala, todas las capas")
	await tree.create_timer(0.5).timeout
	var stack: Node = tree.root.get_node(^"MenuStack")
	var level_db: float = (music.players[&"dark"] as AudioStreamPlayer).volume_db
	stack.push(load("res://src/ui/menus/pause_menu.tscn").instantiate())
	await tree.create_timer(0.5, true).timeout
	assert_true((music.players[&"dark"] as AudioStreamPlayer).volume_db < level_db - 5.0, "con un menú abierto la música baja")
	while stack.is_open():
		stack.pop()
	tree.root.get_node(^"GameState").reset()


func test_music_ducks_when_a_menu_opens() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var music: Node = tree.root.get_node(^"Music")
	var stack: Node = tree.root.get_node(^"MenuStack")
	stack.push(load("res://src/ui/menus/pause_menu.tscn").instantiate())
	await tree.process_frame
	assert_true(music._menu_open, "se entera por MenuStack.changed")
	stack.clear()
	await tree.process_frame
	assert_true(not music._menu_open, "y al cerrarse, también")
	tree.paused = false
