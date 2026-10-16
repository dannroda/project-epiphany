extends "res://tests/test_case.gd"
## El AmbientePreset de una sala pone su cámara, viñeta y luz al entrar y devuelve las del nivel al salir; los botones
## del editor lo editan sobre la cámara y el entorno del nivel y lo dejan como estaba.

const LEVEL := "res://levels/ejemplo_ambiente.tscn"


func _look(world: WorldEnvironment) -> Array:
	var tone := AmbientePreset.tone_of(world)
	return [snappedf(tone.vignette, 0.01), snappedf(tone.frame, 0.01), snappedf(world.environment.ambient_light_energy, 0.01)]


func test_room_preset_applies_on_enter_and_restores_on_leave() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.get_node(^"GameState").reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	await tree.create_timer(0.3).timeout
	var level := tree.current_scene
	var world := level.get_node("WorldEnvironment") as WorldEnvironment
	var entrada := level.get_node("PlantaBaja/Entrada") as Room
	var player := tree.get_first_node_in_group(&"player") as Node3D
	var preset := entrada.ambiente
	assert_eq(_look(world), [preset.vignette, preset.frame, preset.ambient_light_energy], "arranca en la entrada con su preset")
	player.global_position = level.get_node("PlantaBaja/Osario").global_position + Vector3(0, -0.5, 0)
	await tree.create_timer(1.0).timeout
	assert_eq(_look(world), [1.0, 0.1, 1.25], "en el osario vuelve el ambiente del nivel")


func test_editor_buttons_edit_on_the_level_nodes_and_restore_them() -> void:
	var level: Node = load(LEVEL).instantiate()
	var room := level.get_node("PlantaBaja/Entrada") as Room
	room.ambiente = room.ambiente.duplicate()
	var world := level.get_node("WorldEnvironment") as WorldEnvironment
	var before := _look(world)
	room.editar_ambiente()
	assert_eq(_look(world), [1.6, 0.16, 0.4], "editar pone el preset en los nodos del nivel")
	AmbientePreset.tone_of(world).vignette = 0.9
	room.guardar_ambiente()
	assert_eq(snappedf(room.ambiente.vignette, 0.01), 0.9, "guardar copia lo de los nodos al preset")
	assert_eq(_look(world), before, "y deja el nivel como estaba")
	level.free()


func _enter_example() -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.get_node(^"GameState").reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	await tree.create_timer(0.3).timeout
	var level := tree.current_scene
	var camera := tree.get_first_node_in_group(TopDownCamera.GROUP) as TopDownCamera
	return [tree, level, level.get_node("WorldEnvironment"), camera, tree.get_first_node_in_group(&"player")]


func test_changing_rooms_fades_the_vignette() -> void:
	var setup: Array = await _enter_example()
	var tree: SceneTree = setup[0]
	var level: Node = setup[1]
	var camera: TopDownCamera = setup[3]
	var tone := AmbientePreset.tone_of(setup[2])
	var start: float = (level.get_node("PlantaBaja/Entrada") as Room).ambiente.vignette
	(setup[4] as Node3D).global_position = level.get_node("PlantaBaja/Osario").global_position + Vector3(0, -0.5, 0)
	var osario := level.get_node("PlantaBaja/Osario") as Room
	while camera.room != osario:
		await tree.physics_frame
	await tree.create_timer(camera.transition_time * 0.4).timeout
	assert_true(tone.vignette > minf(start, 1.0) + 0.01 and tone.vignette < maxf(start, 1.0) - 0.01, "a mitad del cambio va entre una y otra (%.2f)" % tone.vignette)
	await tree.create_timer(1.0).timeout
	assert_eq(snappedf(tone.vignette, 0.01), 1.0, "y termina en la del nivel")


func test_cinematic_mode_drops_the_room_frame_and_gives_it_back() -> void:
	var setup: Array = await _enter_example()
	var tree: SceneTree = setup[0]
	var level: Node = setup[1]
	var world: WorldEnvironment = setup[2]
	var camera: TopDownCamera = setup[3]
	var cinematic := [camera.cinematic_look.vignette, camera.cinematic_look.frame]
	camera.set_cinematic(true, true)
	assert_eq(_look(world).slice(0, 2), cinematic, "la cinemática pone su viñeta, sin marco")
	(setup[4] as Node3D).global_position = level.get_node("PlantaBaja/Osario").global_position + Vector3(0, -0.5, 0)
	await tree.create_timer(1.2).timeout
	assert_eq(_look(world).slice(0, 2), cinematic, "cambiar de sala no la pisa")
	camera.set_cinematic(false)
	await tree.create_timer(camera.cinematic_tone_time * 0.4).timeout
	assert_true(AmbientePreset.tone_of(world).frame > 0.0 and AmbientePreset.tone_of(world).frame < 0.1, "vuelve con fundido")
	await tree.create_timer(1.0).timeout
	assert_eq(_look(world), [1.0, 0.1, 1.25], "y queda la de la sala nueva")
