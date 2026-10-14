extends "res://tests/test_case.gd"

const LEVEL := "res://levels/overworld.tscn"
const ARROW := preload("res://src/items/arrow/arrow.tscn")


func _press(tree: SceneTree, action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	var release := InputEventAction.new()
	release.action = action
	Input.parse_input_event(release)
	for i in 3:
		await tree.physics_frame


func _face(player: PlayerCharacter, direction: Vector3) -> void:
	player.model.look_at(player.model.global_position - direction.normalized(), Vector3.UP)


func _load(tree: SceneTree, items: Array) -> Array:
	var state: Node = tree.root.get_node(^"GameState")
	state.reset()
	for entry in items:
		state.give(Items.get_item(entry[0]), entry[1])
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	for enemy in tree.get_nodes_in_group(&"enemies"):
		enemy.free()
	await tree.physics_frame
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	player.health.invulnerability_time = 0.0
	return [state, tree.current_scene, player]


func _open_chest(tree: SceneTree, chest: Chest, player: PlayerCharacter) -> void:
	var stack: Node = tree.root.get_node(^"MenuStack")
	chest.interactable.interact(player)
	await tree.create_timer(1.0).timeout
	while stack.is_open():
		stack.pop()
	await tree.create_timer(1.2).timeout


func _bomb_wall(tree: SceneTree, wall: CrackedWall, player: PlayerCharacter) -> void:
	var out := wall.global_transform.basis.z.normalized()
	player.global_position = wall.global_position + out * 2.1
	_face(player, -out)
	await tree.physics_frame
	await _press(tree, &"item_1")
	await tree.create_timer(1.0).timeout
	player.global_position = wall.global_position + out * 6.0
	var until := Time.get_ticks_msec() + 6000
	while not wall.is_broken and Time.get_ticks_msec() < until:
		await tree.physics_frame
	await tree.create_timer(0.6).timeout


func test_find_the_secrets_with_everything() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var setup: Array = await _load(tree, [[&"bomb_bag", 1], [&"bomb", 30], [&"bow", 1], [&"arrow", 10], [&"bottle_empty", 1]])
	var state: Node = setup[0]
	var level: Node = setup[1]
	var player: PlayerCharacter = setup[2]
	state.item_buttons[0] = &"bomb_bag"

	for secret in [[&"SecretSummit", &"bomb", 5], [&"SecretRavine", &"arrow", 10], [&"SecretCactus", &"bomb", 5]]:
		var wall := level.get_node(NodePath(String(secret[0]) + "Wall")) as CrackedWall
		await _bomb_wall(tree, wall, player)
		assert_eq(wall.is_broken, true, "una bomba abre %s" % secret[0])
		var before: int = state.inventory.count(secret[1])
		await _open_chest(tree, level.get_node(NodePath(String(secret[0]) + "Chest")), player)
		assert_eq(state.inventory.count(secret[1]), mini(before + secret[2], state.inventory.capacity(secret[1])), "%s guarda %s" % [secret[0], secret[1]])
	var lookout := level.get_node(^"SecretLookoutWall") as CrackedWall
	await _bomb_wall(tree, lookout, player)
	await _open_chest(tree, level.get_node(^"SecretLookoutChest"), player)
	assert_eq(state.bottle_with(&"potion") != &"", true, "la cueva del Mirador guarda una poción")
	var hills := level.get_node(^"SecretHillsWall") as CrackedWall
	await _bomb_wall(tree, hills, player)
	assert_eq(hills.is_broken, true, "la grieta de los Cerros se abre")
	assert_true(level.get_node(^"HeartPieceHills").global_position.distance_to(hills.global_position) < 3.0, "y detrás está la pieza de corazón")

	var block_a := level.get_node(^"GroveBlockA") as PushBlock
	var block_b := level.get_node(^"GroveBlockB") as PushBlock
	player.global_position = block_a.global_position + Vector3(4, 0, -4)
	await tree.physics_frame
	for push in [[block_a, Vector3.BACK], [block_a, Vector3.BACK], [block_b, Vector3.RIGHT], [block_b, Vector3.BACK]]:
		assert_true(push[0].try_push(push[1]), "%s avanza hacia %s" % [push[0].name, push[1]])
		await tree.create_timer(0.6).timeout
	await tree.create_timer(0.6).timeout
	assert_eq((level.get_node(^"GroveChest") as Chest).visible, true, "los dos bloques en sus interruptores traen el cofre")
	await _open_chest(tree, level.get_node(^"GroveChest"), player)
	assert_eq(state.inventory.has(&"armor_chainmail"), true, "el cofre guarda la cota")
	assert_eq(state.equipment[ItemData.Category.ARMOR], &"tunic", "la cota no se equipa sola: hay que ir a Equipo")

	var eye := level.get_node(^"CliffEye") as EyeSwitch
	var cliff_gate := level.get_node(^"CliffGate") as Gate
	player.global_position = Vector3(80, 5.3, -22)
	await tree.physics_frame
	var arrow: Projectile = ARROW.instantiate()
	level.add_child(arrow)
	var from := player.global_position + Vector3(0, 1.0, -0.6)
	var info := Items.get_item(&"bow").make_damage(player)
	info.team = EntityConfig.Team.PLAYER
	arrow.launch(from, _flat_to(from, eye) * 20.0, info)
	await tree.create_timer(0.8).timeout
	assert_eq(eye.active, true, "una flecha por encima del abismo despierta el ojo")
	await tree.create_timer(0.8).timeout
	assert_eq(cliff_gate.is_open, true, "el ojo abre el nicho")
	var arrows_capacity: int = state.inventory.capacity(&"arrow")
	await _open_chest(tree, level.get_node(^"QuiverChest"), player)
	assert_eq(state.inventory.capacity(&"arrow"), arrows_capacity + 20, "el carcaj grande suma flechas")
	assert_true(level.get_node(^"HeartPieceCliff").global_position.distance_to(level.get_node(^"RiscoPost").global_position) < 6.0, "la pieza del Risco está del lado del ojo, junto al poste del gancho")
	state.reset()


func test_without_the_bow_the_eye_stays_shut() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var setup: Array = await _load(tree, [])
	var level: Node = setup[1]
	var player: PlayerCharacter = setup[2]
	var eye := level.get_node(^"CliffEye") as EyeSwitch
	var slash := Items.get_item(&"sword_basic").make_damage(player)
	slash.team = EntityConfig.Team.PLAYER
	eye.hurtbox.receive(slash)
	await tree.physics_frame
	assert_eq(eye.active, false, "la espada no despierta el ojo")
	assert_eq((level.get_node(^"CliffGate") as Gate).is_open, false, "el carcaj sigue encerrado")
	setup[0].reset()


func _shoot(tree: SceneTree, level: Node, player: PlayerCharacter, eye: EyeSwitch, from: Vector3) -> void:
	var arrow: Projectile = ARROW.instantiate()
	level.add_child(arrow)
	var info := Items.get_item(&"bow").make_damage(player)
	info.team = EntityConfig.Team.PLAYER
	arrow.launch(from, _flat_to(from, eye) * 20.0, info)
	await tree.create_timer(0.5).timeout


## El arco dispara plano: solo apunta en el plano.
func _flat_to(from: Vector3, eye: EyeSwitch) -> Vector3:
	var to := eye.eye.global_position - from
	to.y = 0.0
	return to.normalized()


func test_the_three_chullpa_eyes_raise_the_sandals_chest() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var setup: Array = await _load(tree, [[&"bow", 1], [&"arrow", 10]])
	var level: Node = setup[1]
	var player: PlayerCharacter = setup[2]
	var chest := level.get_node(^"SandalsChest") as Chest
	var center := chest.global_position + Vector3(0, 1.2, 0)
	player.global_position = chest.global_position + Vector3(0, 0.1, 1.5)
	await tree.physics_frame
	assert_eq(chest.visible, false, "el cofre no está hasta flechar los ojos")
	var eyes: Array[EyeSwitch] = []
	for i in 3:
		eyes.append(level.get_node(NodePath("NecroTomb%d/Eye" % (i + 1))) as EyeSwitch)
	await _shoot(tree, level, player, eyes[0], center)
	await _shoot(tree, level, player, eyes[1], center)
	assert_eq([eyes[0].active, eyes[1].active], [true, true], "cada flecha prende su ojo")
	assert_eq(chest.visible, false, "con dos no alcanza")
	await tree.create_timer(8.0).timeout
	assert_eq(eyes[0].active, false, "los ojos se apagan solos")
	for eye in eyes:
		await _shoot(tree, level, player, eye, center)
	await tree.create_timer(0.6).timeout
	assert_eq(chest.visible, true, "con los tres prendidos a la vez aparece el cofre")
	setup[0].reset()


func test_the_sandals_crash_shakes_the_heart_piece_out_of_the_quenoa() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var setup: Array = await _load(tree, [])
	var level: Node = setup[1]
	var player: PlayerCharacter = setup[2]
	var quenoa := level.get_node(^"SecretTree") as Breakable
	var piece := level.get_node(^"HeartPieceTree") as HeartPiece
	assert_eq(piece.visible, false, "la pieza no está a la vista")
	var slash := Items.get_item(&"sword_basic").make_damage(player)
	slash.team = EntityConfig.Team.PLAYER
	quenoa.hurtbox.receive(slash)
	await tree.physics_frame
	assert_eq([quenoa.broken, piece.visible], [false, false], "la espada no la voltea ni suelta nada")
	var crash := DamageInfo.make(1, 6.0, player, &"dash")
	crash.team = EntityConfig.Team.PLAYER
	quenoa.hurtbox.receive(crash)
	await tree.create_timer(1.2).timeout
	assert_eq([quenoa.broken, piece.visible], [false, true], "el choque de las sandalias la sacude y cae la pieza")
	player.global_position = piece.global_position
	await tree.create_timer(0.6).timeout
	assert_eq(setup[0].get_flag(&"ow_heart_piece_tree"), true, "y se puede tomar")
	var stack: Node = tree.root.get_node(^"MenuStack")
	while stack.is_open():
		stack.pop()
	setup[0].reset()


func test_the_hills_rock_slides_off_its_niche() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var setup: Array = await _load(tree, [[&"bow", 1]])
	var state: Node = setup[0]
	var level: Node = setup[1]
	var player: PlayerCharacter = setup[2]
	var rock := level.get_node(^"SecretRockBlock") as PushBlock
	var chest := level.get_node(^"SecretRockChest") as Chest
	player.global_position = rock.global_position + Vector3(0, 0, -2)
	await tree.physics_frame
	assert_eq(rock.try_push(Vector3.LEFT), false, "la roca no entra al nicho")
	assert_true(rock.try_push(Vector3.BACK), "se corre a un costado")
	await tree.create_timer(0.8).timeout
	assert_true(rock.global_position.distance_to(chest.global_position) > 2.5, "y deja libre el nicho")
	var before: int = state.inventory.count(&"arrow")
	await _open_chest(tree, chest, player)
	assert_eq(state.inventory.count(&"arrow"), mini(before + 10, state.inventory.capacity(&"arrow")), "el cofre del nicho tiene flechas")
	state.reset()


func test_cutting_the_bush_opens_the_stairs_to_a_cave() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var setup: Array = await _load(tree, [[&"bomb_bag", 1]])
	var state: Node = setup[0]
	var level: Node = setup[1]
	var player: PlayerCharacter = setup[2]
	var bush := level.get_node(^"BushCaveBush") as Breakable
	var door := level.get_node(^"BushCaveDoor") as Portal
	var slash := Items.get_item(&"sword_basic").make_damage(player)
	slash.team = EntityConfig.Team.PLAYER
	bush.hurtbox.receive(slash)
	await tree.create_timer(0.6).timeout
	assert_true(not is_instance_valid(bush) or bush.broken, "la espada corta la mata")
	player.global_position = door.global_position + Vector3(0, 0.1, 0)
	await tree.scene_changed
	await tree.create_timer(0.5).timeout
	assert_eq(String(tree.current_scene.name), "BushCave", "debajo hay una escalera a una cuevita")
	player = tree.get_first_node_in_group(&"player") as PlayerCharacter
	var before: int = state.inventory.count(&"bomb")
	await _open_chest(tree, tree.current_scene.get_node(^"BushCaveChest"), player)
	assert_eq(state.get_flag(&"ow_secret_bush_chest"), true, "con un cofre")
	assert_eq(state.inventory.count(&"bomb"), mini(before + 10, state.inventory.capacity(&"bomb")), "de bombas")
	player.global_position = tree.current_scene.get_node(^"ExitPortal").global_position
	await tree.scene_changed
	await tree.create_timer(0.5).timeout
	player = tree.get_first_node_in_group(&"player") as PlayerCharacter
	assert_true(player.global_position.distance_to(tree.current_scene.get_node(^"BushCaveDoor").global_position) < 3.5, "y se sale al lado de la mata")
	state.reset()


func test_the_cumbre_rope_ladder_is_lowered_from_above_and_stays() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var setup: Array = await _load(tree, [])
	var state: Node = setup[0]
	var level: Node = setup[1]
	var player: PlayerCharacter = setup[2]
	var ladder := level.get_node(^"CumbreLadder") as RopeLadder
	player.global_position = (ladder.bottom.get_child(0) as Node3D).global_position + Vector3(0, -0.7, 0)
	await tree.create_timer(1.0).timeout
	assert_true(player.global_position.y < 1.0, "enrollada, desde abajo no se sube (y %.2f)" % player.global_position.y)
	player.global_position = ladder.get_node(^"TopSpot").global_position
	await tree.physics_frame
	ladder.interactable.interact(player)
	assert_eq([state.get_flag(&"ow_cumbre_ladder"), ladder.ladder.visible], [true, true], "desde arriba se descuelga")
	await tree.create_timer(0.8).timeout
	player.global_position = (ladder.top.get_child(0) as Node3D).global_position + Vector3(0, -0.7, 0)
	await tree.create_timer(0.3).timeout
	assert_true(player.is_climbing(), "se baja trepando, sin fundido")
	await _until_off_the_ladder(tree, player)
	assert_true(player.global_position.y < 1.0, "se baja por la soga (y %.2f)" % player.global_position.y)
	await tree.create_timer(0.5).timeout
	player.global_position = (ladder.bottom.get_child(0) as Node3D).global_position + Vector3(0, -0.7, 0)
	await tree.create_timer(0.3).timeout
	assert_true(player.is_climbing(), "y se sube trepando")
	await _until_off_the_ladder(tree, player)
	assert_true(player.global_position.y > 4.5, "y se sube (y %.2f)" % player.global_position.y)
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	await tree.physics_frame
	assert_eq((tree.current_scene.get_node(^"CumbreLadder") as RopeLadder).ladder.visible, true, "al volver sigue colgada")
	state.reset()


func _walk(tree: SceneTree, player: PlayerCharacter, from: Vector3, action: StringName, frames := 150) -> float:
	player.global_position = from
	for i in 10:
		await tree.physics_frame
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	Input.parse_input_event(press)
	var highest := player.global_position.y
	for i in frames:
		await tree.physics_frame
		highest = maxf(highest, player.global_position.y)
	var release := InputEventAction.new()
	release.action = action
	Input.parse_input_event(release)
	return highest


func test_after_the_final_boss_the_dawn_comes_and_the_temple_top_opens() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var setup: Array = await _load(tree, [])
	var state: Node = setup[0]
	var level: Node = setup[1]
	var player: PlayerCharacter = setup[2]
	var after := level.get_node(^"AfterTheEye") as AfterTheEye
	var gate := level.get_node(^"SummitGate") as Gate
	var glow := level.get_node(^"TempleEyeGlow") as Node3D
	var foot := Vector3(-48, 5.3, -33.5)
	assert_eq([gate.is_open, glow.visible], [false, true], "con el ojo despierto la cima está cerrada y el ojo brilla")
	assert_true(await _walk(tree, player, foot, &"move_forward") < 6.0, "la reja no deja subir")
	state.set_flag(&"te_boss_defeated", true)
	await tree.create_timer(0.8).timeout
	assert_eq([gate.is_open, glow.visible], [true, false], "vencido el jefe, se abre la cima y el ojo se apaga")
	assert_eq(after.sun.light_color, after.dawn_color, "y amanece")
	assert_true(await _walk(tree, player, foot, &"move_forward") > 7.0, "la escalinata sube a la cima del templo")
	player.global_position = level.get_node(^"HeartPieceSummit").global_position
	await tree.create_timer(0.6).timeout
	assert_eq(state.get_flag(&"ow_heart_piece_summit"), true, "donde hay una pieza de corazón")
	var stack: Node = tree.root.get_node(^"MenuStack")
	while stack.is_open():
		stack.pop()
	state.reset()


func _until_off_the_ladder(tree: SceneTree, player: PlayerCharacter) -> void:
	var until := Time.get_ticks_msec() + 6000
	while player.is_climbing() and Time.get_ticks_msec() < until:
		await tree.physics_frame
	await tree.create_timer(0.2).timeout
