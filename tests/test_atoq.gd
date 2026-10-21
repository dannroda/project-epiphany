extends "res://tests/test_case.gd"
## El atoq (11.196): jauría de zorros de la cumbre. Aúllan al verte, te rodean, muerden de a uno y huyen con poca vida.

const LEVEL := "res://levels/test/test.tscn"
const ATOQ := preload("res://src/entities/atoq/atoq.tscn")

var tree: SceneTree
var state: Node
var player: PlayerCharacter


func _start(count: int) -> Array[Enemy]:
	tree = Engine.get_main_loop() as SceneTree
	state = tree.root.get_node(^"GameState")
	state.reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	for i in 3:
		await tree.physics_frame
	for enemy in tree.get_nodes_in_group(&"enemies"):
		enemy.free()
	player = tree.get_first_node_in_group(&"player") as PlayerCharacter
	player.health.invulnerability_time = 0.0
	var pack: Array[Enemy] = []
	for i in count:
		var atoq := ATOQ.instantiate() as Enemy
		var angle := TAU * i / count
		atoq.position = player.global_position + Vector3(cos(angle), 0, sin(angle)) * 6.0
		tree.current_scene.add_child(atoq)
		pack.append(atoq)
	return pack


func test_the_pack_howls_then_bites_one_at_a_time() -> void:
	var pack := await _start(3)
	var howled := false
	for i in 30:
		await tree.physics_frame
		howled = howled or pack.any(func(a: Enemy) -> bool: return a.anim_player.current_animation == &"Atoq/howl")
	assert_true(howled, "al verte aúllan")
	var together := 0
	var before := player.health.current
	var hurt := false
	for i in 60 * 10:
		await tree.physics_frame
		var biting := pack.filter(func(a: Enemy) -> bool: return a.attack_runner.is_running())
		if biting.size() > 1:
			together += 1
		if player.health.current < before:
			hurt = true
		player.health.current = player.health.max_health
		before = player.health.current
	assert_eq(together, 0, "nunca muerden dos a la vez")
	assert_true(hurt, "la mordida lastima")
	assert_true(pack.all(func(a: Enemy) -> bool: return a.global_position.distance_to(player.global_position) < 8.0), "se quedan cerca, rodeándote")
	state.reset()


func test_a_hurt_atoq_runs_away() -> void:
	var pack := await _start(1)
	var atoq := pack[0]
	for i in 90:
		await tree.physics_frame
	atoq.health.current = 2
	await tree.create_timer(2.5).timeout
	assert_true(atoq.global_position.distance_to(player.global_position) > 6.0, "con poca vida huye (%.1f m)" % atoq.global_position.distance_to(player.global_position))
	assert_true(not atoq.attack_runner.is_running(), "y no muerde")
	state.reset()


func test_alone_it_wanders() -> void:
	var pack := await _start(1)
	var atoq := pack[0]
	atoq.global_position = player.global_position + Vector3(30, 0, 0)
	var home := atoq.global_position
	var moved := 0.0
	for i in 60 * 6:
		await tree.physics_frame
		moved = maxf(moved, atoq.global_position.distance_to(home))
	assert_true(moved > 0.5 or atoq.wander_point() == Vector3.INF, "sin ver a nadie deambula (%.1f m)" % moved)
	state.reset()
