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
		if i % 3 == 2:
			await tree.process_frame
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
	await saves.load_scenario("templo")
	(tree.get_first_node_in_group(&"player") as Node3D).global_position = Vector3(44, 0, 50)
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


func test_boss_music_is_held_by_each_arena() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var music: Node = tree.root.get_node(^"Music")
	var first := Node.new()
	var second := Node.new()
	tree.root.add_child(first)
	tree.root.add_child(second)
	music.hold_boss(first)
	music.hold_boss(second)
	music.hold_boss(second)
	music.release_boss(first)
	assert_true(music.boss_fight, "la arena que termina no apaga la música de otra")
	second.free()
	assert_true(not music.boss_fight, "una arena que se va del árbol la suelta")
	music.hold_boss(first)
	music.release_boss(first)
	music.hold_boss(first)
	assert_true(music.boss_fight, "se puede volver a tomar")
	first.free()
	assert_true(not music.boss_fight)


func test_boss_bar_shown_again_right_after_hiding_stays() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var hud := (load("res://src/ui/hud/hud.tscn") as PackedScene).instantiate() as Hud
	tree.root.add_child(hud)
	var fight := ArenaFight.new()
	var bar := BossBar.new("X", fight.bar_changed, func() -> float: return 0.5)
	hud.show_boss(bar)
	hud.hide_boss()
	hud.show_boss(bar)
	await tree.create_timer(2.0).timeout
	assert_true(hud.boss_bar.visible and is_equal_approx(hud.boss_bar.modulate.a, 1.0), "la barra no se esconde por el fundido anterior")
	assert_eq(bar.phase(), 0, "sin fases, fase 0")
	hud.free()
	fight.free()


## Muchos golpes en el mismo cuadro no apilan reproductores sin límite (16.36): hasta MAX_SAME_PER_FRAME del mismo
## sonido por cuadro y MAX_VOICES a la vez, cortando el más viejo.
func test_sounds_in_one_frame_are_capped() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var feel: Node = tree.root.get_node(^"Feel")
	tree.root.get_node(^"GameState").reset()
	tree.change_scene_to_file("res://levels/test.tscn")
	await tree.scene_changed
	await tree.process_frame
	var voices := func() -> int:
		return tree.current_scene.get_children().filter(func(n: Node) -> bool: return n is AudioStreamPlayer3D and not n.is_queued_for_deletion()).size()
	var start: int = voices.call()
	for i in 10:
		feel.sfx(&"hit", Vector3.ZERO)
	assert_eq(voices.call() - start, feel.MAX_SAME_PER_FRAME, "el mismo sonido, pocas copias por cuadro")
	for i in 20:
		await tree.process_frame
		for sound in [&"hit", &"block", &"break"]:
			feel.sfx(sound, Vector3.ZERO)
	assert_true(voices.call() <= feel.MAX_VOICES, "nunca más de MAX_VOICES a la vez (%d)" % voices.call())
	assert_true(feel._sounds[&"boom"].size() == 1 and feel._sounds[&"boom"][0] is AudioStreamWAV, "lo que no tiene .ogg se sintetiza")
	assert_true(not feel._sounds[&"hit"][0] is AudioStreamWAV, "lo que tiene .ogg no se sintetiza de más")
