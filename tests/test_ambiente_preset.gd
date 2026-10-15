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
