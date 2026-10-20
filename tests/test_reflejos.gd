extends "res://tests/test_case.gd"
## 11.27, el santuario de reflejos: cada sala se resuelve solo con el escudo espejo y la espada.

const LEVEL := "res://levels/reflejos.tscn"

var tree: SceneTree
var level: Node
var player: PlayerCharacter
var state: Node


func _start() -> void:
	tree = Engine.get_main_loop() as SceneTree
	state = tree.root.get_node(^"GameState")
	state.reset()
	state.give(Items.get_item(&"shield_mirror"))
	state.equip(Items.get_item(&"shield_mirror"))
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	await tree.create_timer(0.3).timeout
	level = tree.current_scene
	player = tree.get_first_node_in_group(&"player") as PlayerCharacter
	player.health.make_invulnerable(60.0)
	for enemy in tree.get_nodes_in_group(&"enemies"):
		if not enemy is Turret:
			enemy.free()


func _node(path: String) -> Node3D:
	return level.get_node(NodePath(path)) as Node3D


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


func _stand(at: Vector3) -> void:
	hold_block(player, false)
	player.global_position = Vector3(at.x, at.y + 0.25, at.z)
	player.velocity = Vector3.ZERO
	await _frames(3)


## Con el escudo en alto mirando a `facing`.
func _block_facing(at: Vector3, facing: Vector3) -> void:
	await _stand(at)
	facing = facing.normalized()
	player.model.look_at(player.model.global_position - facing, Vector3.UP)
	hold_block(player, true)
	use_gamepad()
	await _frames(8)


func _sword_hit(target: Node) -> void:
	var info := DamageInfo.make(1, 0.0, player)
	info.team = player.hurtbox.team
	target.get_node(^"Hurtbox").receive(info)
	await tree.create_timer(0.4).timeout


func _beam_z(sun: String) -> float:
	return (_node(sun).get_node(^"Beam") as Node3D).global_position.z


func test_the_angle_room_takes_a_diagonal_shield_and_a_mirror_bounce() -> void:
	await _start()
	var door := _node("AnguloDoor") as Door
	var a := _node("AnguloCrystalA") as LightReceiver
	var b := _node("AnguloCrystalB") as LightReceiver
	var z := _beam_z("AnguloSun")
	await _block_facing(Vector3(a.global_position.x, 0, z), Vector3(1, 0, -1))
	assert_true(await _until(func() -> bool: return a.active, 2.0), "en diagonal, el escudo sube el sol al cristal de la pared norte")
	assert_true(not door.is_open, "falta el otro")
	var mirror := _node("AnguloMirror")
	await _block_facing(Vector3(mirror.global_position.x, 0, z), Vector3(1, 0, 1))
	assert_true(await _until(func() -> bool: return b.active, 2.0), "el escudo baja el sol al espejo y el espejo lo lleva al cristal del rincón")
	assert_true(await _until(func() -> bool: return door.is_open, 3.0), "los dos cristales abren la puerta a Orbes")
	hold_block(player, false)
	state.reset()


func test_the_corner_crystal_cannot_be_reached_without_the_mirror() -> void:
	await _start()
	var b := _node("AnguloCrystalB") as LightReceiver
	var z := _beam_z("AnguloSun")
	for x in [4.0, 7.0, 10.0, 12.0]:
		var to := b.global_position - Vector3(x, 0, z)
		var out := to.normalized()
		await _block_facing(Vector3(x, 0, z), Vector3.RIGHT + out)
		await _frames(4)
		assert_true(player.shield.is_catching_light(), "desde x = %.0f el escudo ataja el sol" % x)
		assert_true(not b.active, "desde x = %.0f el muro tapa el rincón" % x)
	hold_block(player, false)
	state.reset()


func test_the_orbs_room_raises_the_bridge_and_opens_the_door_for_a_while() -> void:
	await _start()
	var eye := _node("OrbesEye") as EyeSwitch
	var timed := _node("OrbesTimedEye") as EyeSwitch
	var door := _node("OrbesDoor") as Door
	var bridge := _node("OrbesBridge0") as Bridge
	var turret := _node("OrbesTurretW") as Turret
	var south := _node("OrbesPit").global_position.z + 5.0
	assert_true(bridge.position.y < -1.0, "el puente empieza hundido")
	await _block_facing(Vector3(eye.global_position.x, 0, south), Vector3.FORWARD)
	turret.fire_at(player)
	assert_true(await _until(func() -> bool: return eye.active, 4.0), "un orbe devuelto al ojo de la pared norte")
	assert_true(await _until(func() -> bool: return bridge.position.y > -0.05 and bridge.position.y < 0.05, 4.0), "sube el puente sobre el abismo")
	turret = _node("OrbesTurretE") as Turret
	await _block_facing(Vector3(timed.global_position.x, 0, south), Vector3.FORWARD)
	turret.fire_at(player)
	assert_true(await _until(func() -> bool: return door.is_open, 4.0), "el ojo con tiempo abre la puerta a Giros")
	hold_block(player, false)
	assert_true(await _until(func() -> bool: return not door.is_open, 9.0), "a los 6 s se vuelve a cerrar")
	var plate := _node("OrbesPlate")
	await _stand(plate.global_position)
	assert_true(await _until(func() -> bool: return door.is_open, 3.0), "la placa del otro lado la deja abierta")
	await _stand(plate.global_position + Vector3(0, 0, -4))
	await tree.create_timer(1.0).timeout
	assert_true(door.is_open and state.get_flag(&"ow_reflex_orbs_plate") == true, "y queda abierta")
	state.reset()


func test_the_turns_room_chains_mirror_shield_and_mirror_while_the_shutter_is_open() -> void:
	await _start()
	var shutter := _node("GirosShutter") as Gate
	var mirror_a := _node("GirosMirrorA") as RotatingMirror
	var mirror_b := _node("GirosMirrorB") as RotatingMirror
	var crystal := _node("GirosCrystal") as LightReceiver
	var door := _node("GirosDoor") as Door
	await _stand(mirror_b.global_position + Vector3(0, 0, 3))
	await _sword_hit(mirror_a)
	await _sword_hit(mirror_b)
	assert_true(not shutter.is_open, "la persiana empieza cerrada")
	await _sword_hit(_node("GirosSwitch"))
	assert_true(await _until(func() -> bool: return shutter.is_open, 2.0), "un espadazo al cristal del poste la abre")
	await _block_facing(Vector3(mirror_b.global_position.x, 0, mirror_a.global_position.z), Vector3(1, 0, -1))
	assert_true(await _until(func() -> bool: return crystal.active, 3.0), "espejo, escudo y espejo llevan el sol al nicho")
	assert_true(await _until(func() -> bool: return door.is_open, 3.0), "y el cristal abre la puerta a la Corona")
	hold_block(player, false)
	assert_true(await _until(func() -> bool: return not shutter.is_open, 9.0), "la persiana se vuelve a cerrar sola")
	state.reset()


## El nicho solo recibe el rayo que sale derecho del segundo espejo: ni desde el rayo del sol ni desde el del primer
## espejo lejos de su columna, gire adonde gire.
func test_the_turns_room_niche_takes_only_the_full_chain() -> void:
	await _start()
	var crystal := _node("GirosCrystal") as LightReceiver
	var mirror_a := _node("GirosMirrorA") as RotatingMirror
	var mirror_b := _node("GirosMirrorB") as RotatingMirror
	await _stand(mirror_b.global_position + Vector3(0, 0, 3))
	await _sword_hit(mirror_a)
	await _sword_hit(mirror_b)
	var sun_x := _node("GirosSun").global_position.x
	var row := mirror_a.global_position.z
	for spot in [Vector3(sun_x, 0, (_node("GirosShutter").global_position.z + row) / 2.0), Vector3(8, 0, row), Vector3(11, 0, row)]:
		var caught := 0
		var post := _node("GirosSwitch") as HitSwitch
		await _until(func() -> bool: return not post.active, 9.0)
		await _sword_hit(post)
		for step in 24:
			var angle := TAU * step / 24.0
			await _block_facing(spot, Vector3(sin(angle), 0, cos(angle)))
			caught += 1 if player.shield.is_catching_light() else 0
			assert_true(not crystal.active, "desde %s mirando a %d°" % [spot, step * 15])
		assert_true(caught > 4, "desde %s el escudo ataja el rayo (%d)" % [spot, caught])
	hold_block(player, false)
	state.reset()


func test_the_crown_crystal_brings_the_heart_piece_chest() -> void:
	await _start()
	var mirror := _node("CoronaMirror") as RotatingMirror
	var crystal := _node("CoronaCrystal") as LightReceiver
	var chest := _node("CoronaChest") as Chest
	assert_true(not chest.visible, "el cofre no está hasta prender el cristal")
	await _stand(mirror.global_position + Vector3(0, 0, 2))
	await _block_facing(Vector3(mirror.global_position.x, 0, crystal.global_position.z), Vector3(1, 0, -1))
	await _frames(4)
	assert_true(not crystal.active, "con el espejo sin girar, el sol va a la pared norte")
	await _stand(mirror.global_position + Vector3(0, 0, 2))
	await _sword_hit(mirror)
	await _block_facing(Vector3(mirror.global_position.x, 0, crystal.global_position.z), Vector3(1, 0, -1))
	assert_true(await _until(func() -> bool: return crystal.active, 3.0), "girado, el escudo lleva el sol al cristal")
	assert_true(await _until(func() -> bool: return chest.visible, 3.0), "aparece el cofre grande")
	assert_eq(chest.item.id, &"heart_piece", "con una pieza de corazón")
	assert_eq(chest.flag, &"ow_reflex_done")
	hold_block(player, false)
	state.reset()


## Parado en el rayo directo, gire adonde gire, el sol no llega al cristal sin el espejo.
func test_the_crown_crystal_is_not_reached_from_the_direct_sun() -> void:
	await _start()
	var crystal := _node("CoronaCrystal") as LightReceiver
	var spot := Vector3(_node("CoronaSun").global_position.x + 1.4, 0, _beam_z("CoronaSun"))
	var caught := 0
	for step in 24:
		var angle := TAU * step / 24.0
		await _block_facing(spot, Vector3(sin(angle), 0, cos(angle)))
		caught += 1 if player.shield.is_catching_light() else 0
		assert_true(not crystal.active, "mirando a %d°" % (step * 15))
	assert_true(caught > 4, "el escudo ataja el sol en varias direcciones (%d)" % caught)
	hold_block(player, false)
	state.reset()


## La navmesh horneada no tiene el puente de Orbes: se camina de la entrada al abismo y de Giros a la Corona.
func test_the_rooms_are_walkable_on_each_side_of_the_chasm() -> void:
	await _start()
	var map := player.get_world_3d().navigation_map
	var pit := _node("OrbesPit").global_position
	for pair in [["Spawn_entrada", pit + Vector3(0, 1.8, 5)], ["GirosSwitch", _node("CoronaCrystal").global_position], ["GirosSwitch", pit + Vector3(0, 1.8, -5)]]:
		var from := NavigationServer3D.map_get_closest_point(map, _node(pair[0]).global_position + Vector3(0, 0, 1.5))
		var to := NavigationServer3D.map_get_closest_point(map, pair[1] + Vector3(-1.5, 0, 0))
		var path := NavigationServer3D.map_get_path(map, from, to, true)
		assert_true(not path.is_empty() and path[-1].distance_to(to) < 0.1, "de %s se camina hasta %s" % [pair[0], pair[1]])
	state.reset()

