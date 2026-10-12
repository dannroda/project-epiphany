extends "res://tests/test_case.gd"
## La Chullpa (11.60): tres pisos apilados, escaleras, huecos que caen a la sala de abajo y mapa por piso.

const LEVEL := "res://levels/chullpa.tscn"
const MapData := preload("res://src/ui/menus/map_data.gd")

var tree: SceneTree
var level: Node
var player: PlayerCharacter
var camera: TopDownCamera


func _start() -> void:
	tree = Engine.get_main_loop() as SceneTree
	tree.root.get_node(^"GameState").reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	await tree.create_timer(0.3).timeout
	level = tree.current_scene
	player = tree.get_first_node_in_group(&"player") as PlayerCharacter
	player.health.invulnerability_time = 0.0
	camera = level.get_node(^"TopDownCamera") as TopDownCamera
	for enemy in tree.get_nodes_in_group(&"enemies"):
		enemy.free()


func _room(path: String) -> Room:
	return level.get_node(path) as Room


func _floor(path: String) -> DungeonFloor:
	return level.get_node(path) as DungeonFloor


func _drop(at: Vector3) -> void:
	player.global_position = at
	player.velocity = Vector3.ZERO
	var until := Time.get_ticks_msec() + 4000
	var airborne := false
	while Time.get_ticks_msec() < until and not (airborne and player.is_on_floor() and camera.room and camera.room.contains(player.global_position)):
		await tree.physics_frame
		airborne = airborne or not player.is_on_floor()
	await tree.create_timer(0.2).timeout


func test_rooms_count_only_their_own_floor() -> void:
	await _start()
	var entrance := _room("PlantaBaja/Entrada")
	assert_true(entrance.contains(Vector3(12, 0, 24)), "la entrada tiene su piso")
	assert_true(not entrance.contains(Vector3(12, 8, 24)), "el rellano de arriba no es la entrada")
	assert_true(_room("PisoAlto/Rellano").contains(Vector3(12, 8, 24)))
	assert_eq(camera.room, entrance, "arranca en la entrada")
	assert_true(not _floor("PisoAlto").visible, "el piso de arriba está oculto")
	assert_true(_floor("PlantaBaja").visible and _floor("Sotano").visible, "el suyo y el de abajo se ven")
	tree.root.get_node(^"GameState").reset()


func test_stairs_go_up_and_back() -> void:
	await _start()
	player.global_position = Vector3(0.6, 0, 20)
	await tree.create_timer(1.2).timeout
	assert_eq(camera.room, _room("PisoAlto/Rellano"), "la escalera lleva al rellano")
	assert_true(absf(player.global_position.y - 8.0) < 0.5, "arriba, en el piso alto (y %.1f)" % player.global_position.y)
	assert_true(_floor("PisoAlto").visible, "ahora se ve el piso alto")
	assert_eq(tree.root.get_node(^"Fader/Rect").color.a, 0.0, "el fundido terminó")
	player.global_position = Vector3(0.6, 8, 20)
	await tree.create_timer(1.2).timeout
	assert_eq(camera.room, _room("PlantaBaja/Entrada"), "y la de bajada vuelve a la entrada")
	assert_true(not _floor("PisoAlto").visible, "el piso alto se oculta otra vez")
	tree.root.get_node(^"GameState").reset()


func test_hole_drops_to_the_room_below() -> void:
	await _start()
	var health := player.health.current
	await _drop(Vector3(32, 0.5, 24))
	assert_eq(camera.room, _room("Sotano/Cripta"), "el hueco de la sala del cofre cae a la cripta")
	assert_true(absf(player.global_position.y + 8.0) < 0.5, "en el sótano (y %.1f)" % player.global_position.y)
	assert_eq(player.health.current, health, "caer a la sala de abajo no lastima")
	assert_true(not _floor("PlantaBaja").visible, "los pisos de arriba se ocultan")
	assert_true(absf(tree.root.get_node(^"GameState").room_entry.y + 8.0) < 0.5, "la entrada de la sala se anota al aterrizar")
	tree.root.get_node(^"GameState").reset()


func test_crypt_ladder_only_goes_up_to_the_entrance() -> void:
	await _start()
	await _drop(Vector3(32, 0.5, 24))
	player.global_position = Vector3(47.4, -8, 20)
	await tree.create_timer(1.2).timeout
	assert_eq(camera.room, _room("PlantaBaja/Entrada"), "la escalera de mano sube a la entrada")
	assert_true(level.find_children("*", "Stairs", true, false).all(func(stairs: Stairs) -> bool: return stairs.to != level.get_node(^"Sotano/CriptaLadder")), "nada baja por ella")
	tree.root.get_node(^"GameState").reset()


func test_bombed_floor_drops_onto_the_island() -> void:
	await _start()
	var cracked := level.get_node(^"PisoAlto/CrackedFloor") as CrackedWall
	await _drop(Vector3(36, 8.5, 26))
	assert_eq(camera.room, _room("PisoAlto/Agrietada"), "el piso agrietado aguanta")
	var explosion := (load("res://src/items/bomb/explosion.tscn") as PackedScene).instantiate() as Node3D
	level.add_child(explosion)
	explosion.global_position = Vector3(36, 8.3, 27)
	player.global_position = Vector3(28, 8.5, 18)
	await tree.create_timer(0.6).timeout
	assert_true(cracked.is_broken, "la bomba lo rompe")
	await _drop(Vector3(36, 8.5, 26))
	assert_eq(camera.room, _room("PlantaBaja/SalaCofre"), "y se cae a la sala del cofre")
	assert_true(absf(player.global_position.y) < 0.5 and Vector2(player.global_position.x, player.global_position.z).distance_to(Vector2(36, 25)) < 1.5, "sobre la isla del cofre (%s)" % player.global_position.snappedf(0.1))
	tree.root.get_node(^"GameState").reset()


func test_chasm_has_no_room_below() -> void:
	await _start()
	await _drop(Vector3(36, 0.5, 14))
	assert_eq(camera.room, _room("PlantaBaja/Abismo"))
	await tree.create_timer(0.8).timeout
	var health := player.health.current
	await _drop(Vector3(36, 0.5, 9))
	assert_eq(camera.room, _room("PlantaBaja/Abismo"), "el abismo devuelve a la sala")
	assert_eq(player.health.current, health - 2, "y lastima")
	tree.root.get_node(^"GameState").reset()


func test_map_shows_the_current_floor() -> void:
	await _start()
	assert_eq(MapData.rooms_on(tree, 1).size(), 4, "cuatro salas por piso")
	var minimap: Node = tree.get_first_node_in_group(&"hud").find_children("*", "", true, false).filter(func(node: Node) -> bool: return node.has_method(&"rooms_around"))[0]
	assert_true(minimap.rooms_around().all(func(room: Room) -> bool: return room.floor_level() == 0), "el minimapa muestra solo la planta baja")
	var doors := MapData.doors(tree).filter(func(door: Array) -> bool: return MapData.near_room(_room("PlantaBaja/Entrada"), door[0]))
	assert_eq(doors.size(), 3, "la entrada tiene sus tres puertas (de las de arriba y abajo, ninguna)")
	tree.root.get_node(^"GameState").reset()
