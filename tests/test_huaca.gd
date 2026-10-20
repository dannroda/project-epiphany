extends "res://tests/test_case.gd"
## 11.26: la Huaca de los guerreros, prueba de combate opcional del overworld: tres oleadas con la persiana cerrada y
## una pieza de corazón al final.

const LEVEL := "res://levels/huaca.tscn"

var tree: SceneTree
var state: Node
var level: Node
var spawner: WaveSpawner
var door: Door
var piece: HeartPiece


func _start() -> void:
	tree = Engine.get_main_loop() as SceneTree
	state = tree.root.get_node(^"GameState")
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	level = tree.current_scene
	spawner = level.get_node(^"Waves") as WaveSpawner
	door = level.get_node(^"ShutterDoor") as Door
	piece = level.get_node(^"HeartPieceTrial") as HeartPiece
	(tree.get_first_node_in_group(&"player") as PlayerCharacter).health.make_invulnerable(999.0)


func _until(condition: Callable, seconds := 5.0) -> bool:
	var until := Engine.get_physics_frames() + int(seconds * Engine.physics_ticks_per_second)
	while Engine.get_physics_frames() < until:
		if condition.call():
			return true
		await tree.physics_frame
	return condition.call()


func _clear_wave() -> void:
	await _until(func() -> bool: return spawner._alive.size() == spawner.waves()[spawner.wave].get_child_count(), 2.0)
	for enemy: Node3D in spawner._alive.duplicate():
		enemy.health.damage(999)


func test_three_waves_close_the_shutter_and_give_a_heart_piece_once() -> void:
	tree = Engine.get_main_loop() as SceneTree
	tree.root.get_node(^"GameState").reset()
	await _start()
	assert_true(not piece.visible, "la pieza no está a la vista antes de ganar")
	assert_true(await _until(func() -> bool: return spawner.running and not door.is_open), "al entrar empiezan las oleadas y se cierra la persiana")
	var kinds := []
	for wave in spawner.waves():
		var scenes := []
		for spawn: WaveSpawn in wave.get_children():
			scenes.append(spawn.enemy.resource_path.get_file().get_basename())
		kinds.append(scenes)
	assert_eq(kinds[0], ["skeleton_chullpa", "skeleton_chullpa", "skeleton_chullpa", "skeleton_chullpa"], "ola 1: cuatro esqueletos")
	assert_eq(kinds[1], ["shield_skeleton_chullpa", "shield_skeleton_chullpa", "archer_skeleton_chullpa", "archer_skeleton_chullpa"], "ola 2: escudos y arqueros")
	assert_eq(kinds[2], ["warden_mini", "skeleton_chullpa", "skeleton_chullpa"], "ola 3: el Ojo Vigía mini y dos esqueletos")
	await _clear_wave()
	assert_true(await _until(func() -> bool: return spawner.wave == 1 and spawner._alive.size() == 4, 4.0), "sigue la segunda")
	assert_true(not door.is_open, "entre oleadas la persiana sigue cerrada")
	var archers := spawner._alive.filter(func(enemy: Node3D) -> bool: return enemy.scene_file_path.ends_with("archer_skeleton_chullpa.tscn"))
	await tree.create_timer(3.0).timeout
	for archer: Node3D in archers:
		assert_true(archer.global_position.y > 0.5, "el arquero sigue arriba de su tarima (%s)" % archer.global_position)
	await _clear_wave()
	assert_true(await _until(func() -> bool: return spawner.wave == 2 and spawner._alive.size() == 3, 4.0), "sigue la tercera")
	await _clear_wave()
	assert_true(await _until(func() -> bool: return door.is_open and piece.visible, 6.0), "vencida la tercera se abre la persiana y aparece la pieza")
	assert_true(state.get_flag(&"ow_trial_waves") == true)
	await _start()
	assert_true(spawner.active and not spawner.running, "al volver no se repite")
	await tree.create_timer(1.0).timeout
	assert_true(door.is_open and spawner._alive.is_empty(), "sin enemigos y con la persiana abierta")
	assert_true(piece.visible, "la pieza sigue ahí hasta tomarla")
	state.set_flag(&"ow_heart_piece_trial", true)
	await _start()
	assert_true(not piece.visible, "tomada no vuelve")
	state.reset()


func test_nothing_in_the_trial_needs_the_hookshot_or_the_mirror_shield() -> void:
	var root: Node = (load(LEVEL) as PackedScene).instantiate()
	for spawn: WaveSpawn in root.find_children("*", "WaveSpawn", true, false):
		var path := spawn.enemy.resource_path
		assert_true(not "armored" in path and not "mummy" in path, "%s: sin acorazados ni momias" % path)
	root.free()
