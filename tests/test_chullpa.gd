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


## Un punto de la sala en sus propias coordenadas: x y z desde su centro, y desde su piso.
func _in(path: String, local: Vector3) -> Vector3:
	var room := _room(path)
	return Vector3(room.global_position.x, (room.get_parent() as Node3D).global_position.y, room.global_position.z) + local


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
	assert_true(entrance.contains(_in("PlantaBaja/Entrada", Vector3.ZERO)), "la entrada tiene su piso")
	assert_true(not entrance.contains(_in("PisoAlto/Rellano", Vector3.ZERO)), "el rellano de arriba no es la entrada")
	assert_true(_room("PisoAlto/Rellano").contains(_in("PisoAlto/Rellano", Vector3.ZERO)))
	assert_eq(camera.room, entrance, "arranca en la entrada")
	assert_true(not _floor("PisoAlto").visible, "el piso de arriba está oculto")
	assert_true(_floor("PlantaBaja").visible and _floor("Sotano").visible, "el suyo y el de abajo se ven")
	tree.root.get_node(^"GameState").reset()


func test_stairs_go_up_and_back() -> void:
	await _start()
	player.global_position = _in("PlantaBaja/Entrada", Vector3(-11.4, 0, -4))
	await tree.create_timer(1.2).timeout
	assert_eq(camera.room, _room("PisoAlto/Rellano"), "la escalera lleva al rellano")
	assert_true(absf(player.global_position.y - 8.0) < 0.5, "arriba, en el piso alto (y %.1f)" % player.global_position.y)
	assert_true(_floor("PisoAlto").visible, "ahora se ve el piso alto")
	assert_eq(tree.root.get_node(^"SceneFlow/Rect").color.a, 0.0, "el fundido terminó")
	player.global_position = _in("PisoAlto/Rellano", Vector3(-11.4, 0, -4))
	await tree.create_timer(1.2).timeout
	assert_eq(camera.room, _room("PlantaBaja/Entrada"), "y la de bajada vuelve a la entrada")
	assert_true(not _floor("PisoAlto").visible, "el piso alto se oculta otra vez")
	tree.root.get_node(^"GameState").reset()


func test_hole_drops_to_the_room_below() -> void:
	await _start()
	var health := player.health.current
	await _drop(_in("PlantaBaja/SalaCofre", Vector3(-4, 0.5, 0)))
	assert_eq(camera.room, _room("Sotano/Cripta"), "el hueco de la sala del cofre cae a la cripta")
	assert_true(absf(player.global_position.y + 8.0) < 0.5, "en el sótano (y %.1f)" % player.global_position.y)
	assert_eq(player.health.current, health, "caer a la sala de abajo no lastima")
	assert_true(not _floor("PlantaBaja").visible, "los pisos de arriba se ocultan")
	assert_true(absf(tree.root.get_node(^"GameState").room_entry.y + 8.0) < 0.5, "la entrada de la sala se anota al aterrizar")
	tree.root.get_node(^"GameState").reset()


func test_an_enemy_that_falls_to_the_floor_below_stays_visible() -> void:
	await _start()
	await _drop(_in("PlantaBaja/SalaCofre", Vector3(-4, 0.5, 0)))
	var enemy: Enemy = load("res://src/entities/enemy.tscn").instantiate()
	enemy.config = load("res://data/entities/skeleton.tres")
	enemy.remove_from_group(Room.SLEEPERS)
	_floor("PlantaBaja").add_child(enemy)
	enemy.global_position = player.global_position + Vector3(1.5, 1.5, 0.0)
	var airborne := false
	for i in 120:
		await tree.physics_frame
		airborne = airborne or not enemy.is_on_floor()
		if airborne and enemy.is_on_floor():
			break
	await tree.physics_frame
	assert_eq(DungeonFloor.of(enemy), _floor("Sotano"), "un esqueleto de la planta baja que cae al sótano pasa a ese piso")
	assert_true(enemy.is_visible_in_tree(), "así no queda invisible con la planta baja oculta")
	enemy.free()
	tree.root.get_node(^"GameState").reset()


func test_crypt_ladder_only_goes_up_to_the_room_above() -> void:
	await _start()
	await _drop(_in("PlantaBaja/SalaCofre", Vector3(-4, 0.5, 0)))
	player.global_position = _in("Sotano/Cripta", Vector3(11.4, 0, -4))
	await tree.create_timer(1.2).timeout
	assert_eq(camera.room, _room("PlantaBaja/SalaCofre"), "la escalera de mano sube a la sala de arriba")
	var ladder := level.get_node(^"Sotano/CriptaLadder") as Node3D
	assert_true(Vector2(player.global_position.x - ladder.global_position.x, player.global_position.z - ladder.global_position.z).length() < 3.0, "justo encima de la escalera (%s)" % player.global_position.snappedf(0.1))
	assert_true(level.find_children("*", "Stairs", true, false).all(func(stairs: Stairs) -> bool: return stairs.to != level.get_node(^"Sotano/CriptaLadder")), "nada baja por ella")
	tree.root.get_node(^"GameState").reset()


func _until(condition: Callable, seconds := 15.0) -> bool:
	var until := Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < until:
		if condition.call():
			return true
		await tree.physics_frame
	return false


func _explode(at: Vector3) -> void:
	var explosion := (load("res://src/items/bomb/explosion.tscn") as PackedScene).instantiate() as Node3D
	level.add_child(explosion)
	explosion.global_position = at
	await tree.create_timer(0.6).timeout


func test_pushing_the_pot_onto_the_plate_opens_the_leaps_room() -> void:
	await _start()
	var door := level.get_node(^"PisoAlto/SaltosDoor") as Door
	var weight := level.get_node(^"PisoAlto/RellanoWeight") as FloorSwitch
	var pot := level.get_node(^"PisoAlto/RellanoPot") as BigPot
	await _drop(_in("PisoAlto/Rellano", Vector3(0, 0.5, 0)))
	assert_eq(camera.room, _room("PisoAlto/Rellano"))
	assert_true(_room("PisoAlto/Rellano").contains(pot.global_position), "la vasija está en el rellano")
	assert_true(not door.is_open, "la puerta a la sala de los saltos está cerrada")
	player.global_position = weight.global_position + Vector3(0, 0.5, 0)
	await tree.create_timer(0.3).timeout
	assert_true(not weight.active, "el player no aprieta la placa de peso")
	player.global_position = pot.global_position + Vector3(0, 0.5, -2)
	await tree.create_timer(0.3).timeout
	for i in 2:
		assert_true(pot.try_push(Vector3.BACK), "la vasija avanza hacia la placa")
		await tree.create_timer(0.7).timeout
	assert_true(await _until(func() -> bool: return weight.active, 2.0), "dos empujones y la vasija aprieta la placa")
	assert_true(await _until(func() -> bool: return door.is_open, 8.0), "y se abre la puerta")
	tree.root.get_node(^"GameState").reset()


## 11.176: la llave chica de la Cripta oscura abre la sala de la Momia, así el sótano es obligatorio.
func test_the_mummy_door_takes_the_crypt_key() -> void:
	await _start()
	var door := level.get_node(^"PisoAlto/AgrietadaDoor") as Door
	var state: Node = tree.root.get_node(^"GameState")
	assert_eq(door.kind, Door.Kind.LOCKED, "la puerta a la Momia es con llave")
	assert_eq((level.get_node(^"Sotano/KeyChest") as Chest).item.id, &"small_key", "la llave chica está en la Cripta oscura")
	assert_true(not door.is_open and door.interactable.enabled, "cerrada hasta usar la llave")
	state.current_dungeon_state().small_keys = 1
	assert_true(door.try_unlock(), "con la llave abre")
	assert_eq(state.current_dungeon_state().small_keys, 0, "y la gasta")
	state.reset()


## 11.176: la llave del jefe espera del otro lado de los huecos de 2NO (volver con la pluma); el Mausoleo es de paso.
func test_the_boss_key_waits_across_the_leaps_holes() -> void:
	await _start()
	var saltos := _room("PisoAlto/Saltos")
	var boss_key := level.get_node(^"PisoAlto/BossKeyChest") as Chest
	var compass := level.get_node(^"PisoAlto/CompassChest") as Chest
	assert_eq(boss_key.item.id, &"boss_key")
	assert_true(saltos.contains(boss_key.global_position) and saltos.contains(compass.global_position), "las dos en la sala de los saltos")
	var grid := level.get_node(^"PisoAlto/GridMap") as GridMap
	var holes := func(from: float, to: float) -> int:
		var count := 0
		for z in range(int(minf(from, to)), int(maxf(from, to)) + 1):
			var item := grid.get_cell_item(grid.local_to_map(grid.to_local(Vector3(boss_key.global_position.x, grid.global_position.y, z))))
			if item != -1 and grid.mesh_library.get_item_name(item).begins_with("Hueco"):
				count += 1
		return count
	assert_true(holes.call(boss_key.global_position.z, saltos.global_position.z) > 0, "la llave del jefe está del otro lado de los huecos")
	assert_eq(holes.call(compass.global_position.z, compass.global_position.z + 2.0), 0, "la brújula, de este lado")
	var sotano := level.get_node(^"Sotano/GridMap") as GridMap
	var mausoleo := _room("Sotano/Mausoleo")
	for cell in sotano.get_used_cells():
		var at := sotano.to_global(sotano.map_to_local(cell))
		if mausoleo.contains(Vector3(at.x, mausoleo.global_position.y, at.z)):
			assert_true(not sotano.mesh_library.get_item_name(sotano.get_cell_item(cell)).begins_with("Hueco"), "el Mausoleo no tiene huecos (%s)" % cell)
	assert_true(level.get_node_or_null(^"Sotano/BossKeyChest") == null, "ni cofre")
	tree.root.get_node(^"GameState").reset()


func test_the_ossuary_keeps_the_big_pots() -> void:
	await _start()
	for pot_name in [^"PlantaBaja/OsarioPot1", ^"PlantaBaja/OsarioPot2"]:
		var pot := level.get_node(pot_name) as Node3D
		assert_true(pot is BigPot, "%s es una vasija grande" % pot_name)
		assert_true(_room("PlantaBaja/Osario").contains(pot.global_position), "%s está en el osario" % pot_name)
	tree.root.get_node(^"GameState").reset()


func test_the_mummy_guardian_breaks_the_floor_onto_the_feather() -> void:
	await _start()
	var fight := level.get_node(^"PisoAlto/MummyFight") as ArenaFight
	var mummy := fight.get_node(^"Mummy") as MummyGuard
	var cracked := level.get_node(^"PisoAlto/CrackedFloor") as CrackedWall
	player.health.reset(40)
	await _drop(_in("PisoAlto/Agrietada", Vector3(8, 0.5, 6)))
	assert_eq(camera.room, _room("PisoAlto/Agrietada"))
	await _explode(_in("PisoAlto/Agrietada", Vector3(0, 0.3, 3)))
	assert_true(not cracked.is_broken, "la bomba ya no rompe el piso")
	assert_true(await _until(func() -> bool: return mummy.state != MummyGuard.State.IDLE), "arranca la pelea")
	assert_true(not (level.get_node(^"PisoAlto/MiradorDoor") as Door).is_open, "se cierra la puerta al mirador")
	mummy.hurtbox.receive(DamageInfo.make(2, 0.0, player))
	assert_eq(mummy.health.current, mummy.health.max_health, "sin trabarse, la espada rebota")
	assert_true(await _until(func() -> bool: return mummy.state == MummyGuard.State.STUCK, 20.0), "cae y queda trabada")
	while not mummy.is_dead and mummy.is_vulnerable():
		mummy.hurtbox.receive(DamageInfo.make(2, 0.0, player))
		await tree.create_timer(0.3).timeout
	assert_true(mummy.is_dead, "trabada, la espada la vence sin ítems")
	assert_true(await _until(func() -> bool: return fight.active), "pelea ganada")
	assert_true(cracked.is_broken, "al caer rompe el piso")
	await _drop(_in("PisoAlto/Agrietada", Vector3(0, 0.5, 2)))
	assert_eq(camera.room, _room("PlantaBaja/SalaCofre"), "y se cae a la sala del cofre")
	var island := _in("PlantaBaja/SalaCofre", Vector3(0, 0, 1))
	assert_true(absf(player.global_position.y - island.y) < 0.5 and Vector2(player.global_position.x, player.global_position.z).distance_to(Vector2(island.x, island.z)) < 1.5, "sobre la isla de la pluma (%s)" % player.global_position.snappedf(0.1))
	tree.root.get_node(^"GameState").reset()


func test_the_mallqui_fills_its_room_with_waves_that_the_feather_jumps() -> void:
	await _start()
	var state: Node = tree.root.get_node(^"GameState")
	state.give(Items.get_item(&"feather"))
	state.assign_button(1, &"feather")
	var fight := level.get_node(^"Sotano/BossFight") as ArenaFight
	var boss := fight.get_node(^"Mallqui") as MummyGuard
	player.health.reset(80)
	await _drop(_in("Sotano/Guardian", Vector3(-6, 0.5, 4)))
	assert_eq(camera.room, _room("Sotano/Guardian"))
	assert_true(await _until(func() -> bool: return boss.state != MummyGuard.State.IDLE, 20.0), "arranca la pelea")
	assert_true(not (level.get_node(^"Sotano/BossDoor") as Door).is_open, "se cierra la puerta del jefe")
	var far := await _dodge_the_landing(boss)
	var before := player.health.current
	assert_true(await _until(func() -> bool: return player.health.current < before, 4.0), "la onda llega a %.1f m: no se esquiva caminando" % far)
	assert_true(far > 8.0, "lejos del golpe")
	assert_true(await _until(func() -> bool: return boss.state == MummyGuard.State.STUCK, 5.0), "queda trabado")
	assert_true(await _until(func() -> bool: return boss._rings.is_empty(), 5.0))
	player.health.reset(80)
	await _dodge_the_landing(boss)
	before = player.health.current
	assert_true(await _jump_the_wave(boss), "la onda llega")
	assert_eq(player.health.current, before, "saltando con la pluma, la onda pasa por abajo")
	assert_true(await _until(func() -> bool: return boss.state == MummyGuard.State.STUCK, 5.0))
	while boss.health.current * 2 > boss.health.max_health:
		await _until(func() -> bool: return boss.is_vulnerable(), 20.0)
		boss.hurtbox.receive(DamageInfo.make(2, 0.0, player))
		await tree.create_timer(0.3).timeout
	await _until(func() -> bool: return boss.state == MummyGuard.State.HOP, 10.0)
	var falls := 0
	var last := boss.state
	while boss.state != MummyGuard.State.STUCK:
		if boss.state == MummyGuard.State.AIM and boss._aim_locked:
			player.global_position = _far_from(boss.aim_mark.global_position)
		if boss.state != last and boss.state == MummyGuard.State.FALL:
			falls += 1
		last = boss.state
		player.health.reset(80)
		await tree.physics_frame
	assert_eq(falls, 2, "con media vida salta dos veces seguidas")
	while not boss.is_dead:
		player.health.reset(80)
		if boss.is_vulnerable():
			boss.hurtbox.receive(DamageInfo.make(2, 0.0, player))
			await tree.create_timer(0.3).timeout
		else:
			await tree.physics_frame
	assert_true(await _until(func() -> bool: return fight.active), "pelea ganada")
	assert_true(state.get_flag(&"ch_boss_defeated") == true)
	assert_true(await _until(func() -> bool: return (level.get_node(^"Sotano/BossDoor") as Door).is_open, 3.0), "se abre la puerta")
	assert_true(fight.get_node_or_null(^"HeartContainer") != null, "aparece el contenedor de corazón")
	state.reset()


func _far_from(point: Vector3) -> Vector3:
	var best := Vector3.INF
	for corner in [Vector3(-8, 0, -4), Vector3(8, 0, -4), Vector3(-8, 0, 4), Vector3(8, 0, 4)]:
		var at := _in("Sotano/Guardian", corner)
		if best == Vector3.INF or at.distance_to(point) > best.distance_to(point):
			best = at
	return best


## Espera a que fije la sombra y se para en la esquina más lejana; devuelve a cuánto queda.
func _dodge_the_landing(boss: MummyGuard) -> float:
	await _until(func() -> bool: return boss.state == MummyGuard.State.AIM and boss._aim_locked, 20.0)
	var spot := _far_from(boss.aim_mark.global_position)
	player.global_position = spot
	player.velocity = Vector3.ZERO
	return Vector2(spot.x, spot.z).distance_to(Vector2(boss.aim_mark.global_position.x, boss.aim_mark.global_position.z))


func _jump_the_wave(boss: MummyGuard) -> bool:
	var near := func() -> bool:
		for ring in boss._rings:
			var away: Vector3 = (player.global_position - ring.center) * Vector3(1, 0, 1)
			if away.length() - ring.at < 1.6:
				return true
		return false
	if not await _until(near, 5.0):
		return false
	var event := InputEventAction.new()
	event.action = &"item_2"
	event.pressed = true
	Input.parse_input_event(event)
	var release := InputEventAction.new()
	release.action = &"item_2"
	Input.parse_input_event(release)
	await _until(func() -> bool: return boss._rings.is_empty(), 5.0)
	return true


func test_the_entry_blocks_open_the_stairs_gate() -> void:
	await _start()
	var gate := level.get_node(^"PlantaBaja/EntradaGate") as Gate
	var upper := level.get_node(^"PlantaBaja/EntradaBlockA") as PushBlock
	var lower := level.get_node(^"PlantaBaja/EntradaBlockB") as PushBlock
	assert_true(not gate.is_open, "la reja tapa la escalera")
	assert_true(not lower.try_push(Vector3.FORWARD), "los bloques no se empujan en fila")
	await tree.create_timer(0.4).timeout
	assert_true(lower.try_push(Vector3.RIGHT), "el de abajo se corre")
	await tree.create_timer(0.6).timeout
	for i in 2:
		assert_true(upper.try_push(Vector3.FORWARD), "el de arriba sube hacia la placa")
		await tree.create_timer(0.6).timeout
	assert_true(not upper.try_push(Vector3.LEFT), "la placa está entre columnas")
	assert_true(tree.root.get_node(^"GameState").get_flag(&"ch_entry_plate") == true, "queda sobre la placa")
	assert_true(await _until(func() -> bool: return gate.is_open, 3.0), "y se abre la reja de la escalera")
	tree.root.get_node(^"GameState").reset()


func test_the_crypt_waves_reveal_the_map_chest() -> void:
	await _start()
	var waves := level.get_node(^"Sotano/CriptaWaves") as WaveSpawner
	var chest := level.get_node(^"Sotano/MapChest") as Chest
	assert_true(not chest.visible, "el cofre del mapa no está")
	player.health.reset(40)
	await _drop(_in("Sotano/Cripta", Vector3(0, 0.5, 0)))
	assert_true(await _until(func() -> bool: return waves.running, 3.0), "al caer empiezan las oleadas")
	for wave in 2:
		assert_true(await _until(func() -> bool: return not _alive_in("Sotano/Cripta").is_empty(), 4.0), "oleada %d" % (wave + 1))
		await tree.create_timer(0.3).timeout
		for enemy: Enemy in _alive_in("Sotano/Cripta"):
			enemy.health.invulnerability_time = 0.0
			enemy.health.damage(100)
		await tree.create_timer(0.6).timeout
	assert_true(await _until(func() -> bool: return waves.active, 4.0), "ganadas")
	assert_true(chest.visible and chest.interactable.enabled, "aparece el cofre del mapa")
	tree.root.get_node(^"GameState").reset()


func _alive_in(path: String) -> Array:
	var room := _room(path)
	return room.enemies_inside()


func test_chasm_has_no_room_below() -> void:
	await _start()
	await _drop(_in("PlantaBaja/Abismo", Vector3(0, 0.5, 6)))
	assert_eq(camera.room, _room("PlantaBaja/Abismo"))
	await tree.create_timer(0.8).timeout
	var health := player.health.current
	await _drop(_in("PlantaBaja/Abismo", Vector3(0, 0.5, 2)))
	assert_eq(camera.room, _room("PlantaBaja/Abismo"), "el abismo devuelve a la sala")
	assert_eq(player.health.current, health - 2, "y lastima")
	tree.root.get_node(^"GameState").reset()


func test_the_feather_jumps_the_gaps() -> void:
	await _start()
	var state: Node = tree.root.get_node(^"GameState")
	state.give(Items.get_item(&"feather"))
	state.assign_button(1, &"feather")
	for gap: Array in [[_in("PlantaBaja/Abismo", Vector3(0, 0, 4.6)), "PlantaBaja/Abismo"], [_in("PisoAlto/Saltos", Vector3(0, 0, 4.6)), "PisoAlto/Saltos"], [_in("PisoAlto/Mirador", Vector3(0, 0, 4.6)), "PisoAlto/Mirador"]]:
		player.global_position = gap[0]
		await tree.create_timer(0.3).timeout
		var landed := await _jump(&"move_forward")
		assert_true(landed < gap[0].z - 2.6 and absf(player.global_position.y - gap[0].y) < 0.2, "%s: la fila de huecos se salta (z %.2f, y %.2f)" % [gap[1], landed, player.global_position.y])
		assert_eq(camera.room, _room(gap[1]), "%s: sigue en la sala" % gap[1])
	state.reset()


func _jump(action: StringName) -> float:
	_walk(action, true)
	await tree.physics_frame
	var event := InputEventAction.new()
	event.action = &"item_2"
	event.pressed = true
	Input.parse_input_event(event)
	var release := InputEventAction.new()
	release.action = &"item_2"
	Input.parse_input_event(release)
	for i in 90:
		await tree.physics_frame
		if i > 5 and player.movement_state.get_active_state().name != &"Jumping":
			break
	_walk(action, false)
	for i in 10:
		await tree.physics_frame
	return player.global_position.z


func _walk(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	event.strength = 1.0
	Input.parse_input_event(event)


func test_map_shows_the_current_floor() -> void:
	await _start()
	assert_eq(MapData.rooms_on(tree, 1).size(), 4, "cuatro salas por piso")
	var minimap: Node = tree.get_first_node_in_group(&"hud").find_children("*", "", true, false).filter(func(node: Node) -> bool: return node.has_method(&"rooms_around"))[0]
	assert_true(minimap.rooms_around().all(func(room: Room) -> bool: return room.floor_level() == 0), "el minimapa muestra solo la planta baja")
	var doors := MapData.doors(tree).filter(func(door: Array) -> bool: return MapData.near_room(_room("PlantaBaja/Entrada"), door[0]))
	assert_eq(doors.size(), 4, "la entrada tiene sus tres puertas y la escalera (de las de arriba y abajo, ninguna)")
	tree.root.get_node(^"GameState").reset()


func test_a_skeleton_knocked_into_the_chest_hall_holes_lands_in_the_crypt() -> void:
	tree = Engine.get_main_loop() as SceneTree
	tree.root.get_node(^"GameState").reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	await tree.create_timer(0.3).timeout
	level = tree.current_scene
	player = tree.get_first_node_in_group(&"player") as PlayerCharacter
	player.global_position = _in("PlantaBaja/SalaCofre", Vector3(-9, 0.3, 0))
	await tree.create_timer(0.8).timeout
	var skeleton := level.get_node(^"PlantaBaja/SalaCofreEnemy1") as Enemy
	assert_true(_room("PlantaBaja/SalaCofre").contains(skeleton.global_position), "un esqueleto al borde de los huecos")
	skeleton.global_position = _in("PlantaBaja/SalaCofre", Vector3(-2, 0.3, -4))
	assert_true(await _until(func() -> bool: return skeleton.is_on_floor() and skeleton.global_position.y < -7.0, 3.0), "cae por el hueco al piso de abajo")
	assert_true(_room("Sotano/Cripta").contains(skeleton.global_position) and not skeleton.is_dead, "y sigue vivo en la Cripta")
	tree.root.get_node(^"GameState").reset()


## 11.139: la isla de la pluma queda a un hueco de una baldosa del piso del este: con la pluma se sale (y se vuelve) saltando.
func test_the_feather_island_is_one_tile_from_the_east_floor() -> void:
	await _start()
	var grid := level.get_node(^"PlantaBaja/GridMap") as GridMap
	var chest := level.get_node(^"PlantaBaja/FeatherChest") as Node3D
	var cell := grid.local_to_map(grid.to_local(chest.global_position))
	var island := cell
	while grid.get_cell_item(island + Vector3i.RIGHT) != GridMap.INVALID_CELL_ITEM and grid.mesh_library.get_item_name(grid.get_cell_item(island + Vector3i.RIGHT)) == "Piso":
		island += Vector3i.RIGHT
	var gap := 0
	var at := island + Vector3i.RIGHT
	while grid.mesh_library.get_item_name(grid.get_cell_item(at)) != "Piso":
		gap += 1
		at += Vector3i.RIGHT
	assert_eq(gap, 1, "del borde este de la isla al piso hay %d baldosas de hueco" % gap)
	tree.root.get_node(^"GameState").reset()
