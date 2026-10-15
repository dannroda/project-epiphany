extends "res://tests/test_case.gd"
## D4, el Intihuatana de la Cumbre (GDD §8e): el escudo espejo parte la mazmorra; abajo sin él, arriba con él.

const LEVEL := "res://levels/cumbre.tscn"
const ORB := preload("res://src/entities/projectile.tscn")

var tree: SceneTree
var level: Node
var player: PlayerCharacter
var state: Node


func _start(shield := false) -> void:
	tree = Engine.get_main_loop() as SceneTree
	state = tree.root.get_node(^"GameState")
	state.reset()
	if shield:
		state.give(Items.get_item(&"shield_mirror"))
		state.equip(Items.get_item(&"shield_mirror"))
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	await tree.create_timer(0.3).timeout
	level = tree.current_scene
	player = tree.get_first_node_in_group(&"player") as PlayerCharacter
	player.health.invulnerability_time = 0.0
	for enemy in tree.get_nodes_in_group(&"enemies"):
		enemy.free()


func _frames(count: int) -> void:
	for i in count:
		await tree.physics_frame


func _until(condition: Callable, seconds := 5.0) -> bool:
	var until := Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < until:
		if condition.call():
			return true
		await tree.physics_frame
	return false


## Con el escudo en alto mirando a `facing` (entre el haz que llega y adonde sale).
func _reflect_at(at: Vector3, facing: Vector3) -> void:
	player.global_position = at
	player.velocity = Vector3.ZERO
	await _frames(2)
	facing = facing.normalized()
	player.model.look_at(player.model.global_position - facing, Vector3.UP)
	hold_block(player, true)
	use_gamepad()
	await _frames(8)


func _hit(target: Node, from_arrow := false) -> void:
	var source: Node = ORB.instantiate() if from_arrow else player
	var info := DamageInfo.make(1, 0.0, source)
	info.team = player.hurtbox.team
	target.get_node(^"Hurtbox").receive(info)
	if from_arrow:
		source.free()
	await tree.create_timer(0.5).timeout


func _passes(beam: LightBeam, point: Vector3) -> bool:
	for segment in beam.segments:
		var closest := Geometry3D.get_closest_point_to_segment(point, segment[0], segment[1])
		if closest.distance_to(point) < 0.6:
			return true
	return false


func test_the_chamber_crystal_takes_the_shield_and_opens_the_stairs() -> void:
	await _start(true)
	var gate := level.get_node(^"PisoBase/CamaraStairsGate") as Gate
	assert_true(not gate.is_open, "la escalera empieza cerrada")
	await _reflect_at(Vector3(40, 0.25, 10), Vector3(-1, 0, -1))
	assert_true(await _until(func() -> bool: return state.get_flag(&"cu_camara_crystal") == true, 2.0), "el escudo lleva el sol al cristal")
	assert_true(await _until(func() -> bool: return gate.is_open, 3.0), "y abre la reja de la escalera")
	hold_block(player, false)
	state.reset()


func test_the_atrium_crystal_opens_the_pot_niche() -> void:
	await _start(true)
	var gate := level.get_node(^"PisoBase/AtrioNicheGate") as Gate
	await _reflect_at(Vector3(29, 0.25, 16), Vector3(-1, 0, 1))
	assert_true(await _until(func() -> bool: return gate.is_open, 3.0), "el rayo del Atrio abre el nicho de las vasijas")
	hold_block(player, false)
	state.reset()


func test_the_sword_turns_the_mirrors_and_the_sun_reaches_the_crystal() -> void:
	await _start(true)
	var beam := level.get_node(^"PisoCornisa/EspejosSun/Beam") as LightBeam
	var mirror_a := level.get_node(^"PisoCornisa/EspejosMirrorA") as RotatingMirror
	var mirror_b := level.get_node(^"PisoCornisa/EspejosMirrorB") as RotatingMirror
	var door := level.get_node(^"PisoCornisa/TorretasDoor") as Door
	player.global_position = Vector3(44, 8.25, 6)
	await _frames(4)
	var spot := Vector3(28, 9.26, 10)
	assert_true(not _passes(beam, spot), "con los espejos sin girar, el sol no llega al tramo del sur")
	var yaw := mirror_a.rotation.y
	await _hit(mirror_a, true)
	assert_eq(mirror_a.rotation.y, yaw, "una flecha no lo gira")
	await _hit(mirror_a)
	assert_true(absf(mirror_a.rotation.y - yaw - mirror_a.step) < 0.01, "un espadazo lo gira")
	await _hit(mirror_b)
	await _frames(3)
	assert_true(_passes(beam, spot), "girados los dos, el sol cruza la sala por el sur")
	assert_true(not door.is_open, "la puerta de las Torretas sigue cerrada")
	await _reflect_at(Vector3(28, 8.25, 10), Vector3(-1, 0, 1))
	assert_true(await _until(func() -> bool: return door.is_open, 3.0), "el escudo baja el sol al cristal y abre las Torretas")
	hold_block(player, false)
	state.reset()


func test_the_columns_chasm_is_crossed_only_with_the_hookshot() -> void:
	await _start()
	var grid := level.get_node(^"PisoBase/GridMap") as GridMap
	var holes := range(1, 8).filter(func(x: int) -> bool: return grid.get_cell_item(Vector3i(x, 0, 12)) == 10)
	assert_eq(holes.size(), 4, "la grieta mide 4 celdas: el salto largo cruza 3")
	state.give(Items.get_item(&"hookshot"))
	state.assign_button(0, &"hookshot")
	for spec: Array in [[Vector3(12.4, 0.25, 24), "ColumnasWestPost"], [Vector3(2, 0.25, 16), "ColumnasEastPost"]]:
		player.global_position = spec[0]
		player.velocity = Vector3.ZERO
		await tree.create_timer(0.4).timeout
		var post := level.get_node("PisoBase/" + spec[1]) as HookPost
		assert_true(post in player.targeting.possible_targets, "%s está al alcance" % post.name)
		player.targeting.set_target(post)
		var press := InputEventAction.new()
		press.action = &"item_1"
		press.pressed = true
		Input.parse_input_event(press)
		await tree.physics_frame
		var release := InputEventAction.new()
		release.action = &"item_1"
		Input.parse_input_event(release)
		for i in 180:
			await tree.physics_frame
			if i > 3 and player.movement_state.get_active_state().name != &"Hooking":
				break
		await tree.create_timer(0.3).timeout
		player.targeting.clear()
		assert_true(player.global_position.distance_to(post.global_position) < 1.5, "el gancho cruza hasta %s (%s)" % [post.name, player.global_position.snappedf(0.1)])
	state.reset()


func test_the_snowdrift_eye_is_on_the_north_wall_and_the_map_niche_can_be_walked_into() -> void:
	await _start()
	var room := level.get_node(^"PisoBase/Ventisquero") as Room
	var eye := level.get_node(^"PisoBase/VentisqueroEye") as Node3D
	assert_true(eye.global_position.z - room.bounds().position.y < 1.0, "el ojo está en la pared norte, a la vista")
	var map := player.get_world_3d().navigation_map
	var gate := level.get_node(^"PisoBase/MapGate") as Node3D
	var front := NavigationServer3D.map_get_closest_point(map, gate.global_position + Vector3(-1.5, 0, 0))
	var path := NavigationServer3D.map_get_path(map, NavigationServer3D.map_get_closest_point(map, Vector3(40, 0, 21)), front, true)
	assert_true(front.distance_to(gate.global_position + Vector3(-1.5, 0, 0)) < 0.6 and not path.is_empty() and path[-1].distance_to(front) < 0.1, "se llega caminando a la reja del nicho del mapa")
	state.reset()
