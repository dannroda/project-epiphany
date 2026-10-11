extends "res://tests/test_case.gd"
## La prueba de 10.6: de la sala 1 a la 8, la progresión de calma a latido se nota sin leer nada.

const ROOMS := [["Vestibulo", Vector3(24, 0, 66)], ["Hub", Vector3(24, 0, 50)], ["Galeria", Vector3(0, 0, 50)], ["Agrietada", Vector3(48, 0, 52)], ["Pluma", Vector3(48, 0, 58.6)], ["Arena", Vector3(48, 0, 34)], ["Ojos", Vector3(0, 0, 36)], ["Puzzle", Vector3(0, 0, 22.4)], ["Antesala", Vector3(24, 0, 34)]]


func test_doom_rises_room_by_room() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	state.reset()
	tree.change_scene_to_file("res://levels/temple.tscn")
	await tree.scene_changed
	for enemy in tree.get_nodes_in_group(&"enemies"):
		enemy.free()
	var level := tree.current_scene
	var ambience := level.get_node(^"DoomAmbience") as DoomAmbience
	ambience.blend_speed = 100.0
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	player.health.invulnerability_time = 0.0
	var previous := {red = -1.0, fog = -1.0, dust = -1.0, doom = -1.0}
	for entry in ROOMS:
		player.global_position = entry[1]
		await tree.create_timer(1.2).timeout
		player.health.current = player.health.max_health
		var room := level.get_node(String(entry[0])) as Room
		assert_eq(ambience.current_doom(), room.doom, "%s: toma el doom de su sala" % entry[0])
		var red: float = ambience.environment.ambient_light_color.r - ambience.environment.ambient_light_color.b
		assert_true(room.doom >= previous.doom, "%s: el doom nunca baja en el recorrido" % entry[0])
		assert_true(red >= previous.red - 0.001, "%s: la luz vira a rojo" % entry[0])
		assert_true(ambience.environment.fog_density >= previous.fog - 0.0001, "%s: más niebla" % entry[0])
		assert_true(ambience.dust.amount_ratio >= previous.dust - 0.001, "%s: más polvo" % entry[0])
		previous = {red = red, fog = ambience.environment.fog_density, dust = ambience.dust.amount_ratio, doom = room.doom}
	assert_true(previous.red > 0.3, "en la antesala la luz es claramente roja")
	var body := player.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	assert_eq(body.layers, DoomAmbience.LEGIBLE_LAYER, "el player va en la capa legible")
	assert_eq(ambience.sun.light_cull_mask & DoomAmbience.LEGIBLE_LAYER, 0, "el sol rojo no lo ilumina")
	assert_true(ambience.sun.shadow_caster_mask & DoomAmbience.LEGIBLE_LAYER != 0, "pero sigue dando sombra")
	assert_eq(ambience.legible_light.light_cull_mask, DoomAmbience.LEGIBLE_LAYER)
	assert_true((body.get_active_material(0) as BaseMaterial3D).disable_fog, "sin niebla encima")
	var pot := level.find_children("*", "Breakable", true, false)[0]
	assert_true(ambience.legible.any(func(geometry: Node) -> bool: return pot.is_ancestor_of(geometry)), "los objetos también")
	assert_true(previous.fog > 0.02, "y hay niebla")
	var cracks_in := func(room_name: String) -> int:
		var bounds := (level.get_node(room_name) as Room).bounds()
		return ambience.cracks.filter(func(decal: Decal) -> bool: return bounds.has_point(Vector2(decal.global_position.x, decal.global_position.z))).size()
	assert_eq(cracks_in.call("Vestibulo"), 0, "el vestíbulo está intacto")
	assert_true(cracks_in.call("Antesala") > cracks_in.call("Galeria"), "la antesala está más agrietada que la galería")
	var camera := level.get_node(^"TopDownCamera") as TopDownCamera
	ambience._next_tremor = 0.0
	await tree.process_frame
	await tree.process_frame
	assert_true(camera.trauma > 0.0 or not tree.root.get_node(^"Feel").settings.shake_enabled, "tiembla")
	assert_true(ambience._next_tremor < ambience.tremor_interval.x * 0.7, "en el clímax, temblores más seguidos que en calma (próximo en %.1f s)" % ambience._next_tremor)
	state.reset()
