extends "res://tests/test_case.gd"
## Pinchos de piso a ritmo (11.5).

const LEVEL := "res://levels/test.tscn"
const TRAP := preload("res://src/world/spike_trap.tscn")


func _setup() -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.get_node(^"GameState").reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	for i in 3:
		await tree.physics_frame
	var skeleton: Enemy = null
	for enemy in tree.get_nodes_in_group(&"enemies"):
		if enemy is Enemy and skeleton == null:
			skeleton = enemy
		else:
			enemy.free()
	skeleton.bt_player.active = false
	skeleton.stop_moving()
	skeleton.global_position = Vector3(20, 0.25, 20)
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	return [tree, player, skeleton]


func _trap(tree: SceneTree, at: Vector3, period := 2.0, up_time := 0.6) -> SpikeTrap:
	var trap := TRAP.instantiate() as SpikeTrap
	trap.period = period
	trap.up_time = up_time
	tree.current_scene.add_child(trap)
	trap.global_position = at
	return trap


func test_spikes_warn_rise_hurt_and_go_down() -> void:
	var setup: Array = await _setup()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var at := Vector3(player.global_position.x, 0, player.global_position.z)
	var trap := _trap(tree, at)
	var full := player.health.current
	assert_true(not trap.raised and trap.spikes.position.y < -0.7, "arranca abajo, escondida")
	await tree.create_timer(trap.time_to_rise() - 0.2).timeout
	assert_true(not trap.raised and trap.spikes.position.y > SpikeTrap.HIDDEN + 0.1, "antes de subir asoma")
	assert_eq(player.health.current, full, "asomar no lastima")
	await tree.create_timer(0.35).timeout
	assert_true(trap.raised and is_equal_approx(trap.spikes.position.y, 0.0), "sube de golpe")
	assert_eq(player.health.current, full - trap.damage, "arriba lastima al que está encima")
	await tree.create_timer(trap.up_time + 0.4).timeout
	assert_true(not trap.raised and trap.spikes.position.y < -0.7, "y vuelve a bajar")
	trap.queue_free()


func test_spikes_hurt_enemies_too_and_shields_do_not_stop_them() -> void:
	var setup: Array = await _setup()
	var tree: SceneTree = setup[0]
	var skeleton: Enemy = setup[2]
	var trap := _trap(tree, Vector3(skeleton.global_position.x, 0, skeleton.global_position.z), 0.0)
	var full := skeleton.health.current
	for i in 6:
		await tree.physics_frame
	assert_true(trap.raised, "con period 0 quedan siempre arriba")
	assert_true(skeleton.health.current < full, "el esqueleto también se pincha")
	var info := trap._damage()
	var items: Node = tree.root.get_node(^"Items")
	for id: StringName in [&"shield_wood", &"shield_mirror"]:
		assert_true(not info.element in (items.get_item(id) as ItemData).protects_against, "%s no frena los pinchos" % id)
	trap.queue_free()


func test_feather_wing_spikes_leave_a_gap_that_travels() -> void:
	var level: Node3D = (load("res://levels/templo.tscn") as PackedScene).instantiate()
	var traps: Array[SpikeTrap] = []
	for node in level.get_node(^"Planta").get_children():
		if node.name.begins_with("PlumaSpikes"):
			traps.append(node as SpikeTrap)
	assert_eq(traps.size(), 5, "una columna de cinco en el ala de la pluma")
	for t in 24:
		var clock := t * 0.1
		var down := 0
		for trap in traps:
			var phase := fposmod(clock + trap.offset, trap.period)
			if phase < trap.period - trap.up_time:
				down += 1
		assert_true(down >= 2, "siempre queda paso (%d abajo a los %.1f s)" % [down, clock])
	level.free()
