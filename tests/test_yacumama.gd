extends "res://tests/test_case.gd"
## Yacumama (jefa de D3): asoma por sus charcos y escupe; asomada solo la toca el gancho, que la tira al piso junto al
## player, y tirada le pega la espada. Con la mitad de la vida barre la sala con la cola, que se salta. Vencida, deja
## el contenedor de corazón.

const LEVEL := "res://levels/totora.tscn"

var tree: SceneTree
var level: Node
var player: PlayerCharacter
var boss: Yacumama
var fight: ArenaFight
var _hurtable := false


func _start() -> void:
	tree = Engine.get_main_loop() as SceneTree
	tree.root.get_node(^"GameState").reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	await tree.create_timer(0.3).timeout
	level = tree.current_scene
	player = tree.get_first_node_in_group(&"player") as PlayerCharacter
	player.health.invulnerability_time = 0.0
	for enemy in tree.get_nodes_in_group(&"enemies"):
		enemy.free()
	fight = level.get_node(^"PisoBajo/BossFight") as ArenaFight
	boss = fight.get_node(^"Yacumama") as Yacumama
	player.global_position = Vector3(40, 0.2, 9.5)
	player.velocity = Vector3.ZERO
	await _until(func() -> bool: return boss.state != Amaru.State.IDLE, 8.0)


## Espera algo con el player sano (salvo con `_hurtable`).
func _until(done: Callable, seconds: float) -> bool:
	var until := Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < until:
		if done.call():
			return true
		if not _hurtable:
			player.health.current = player.health.max_health
		await tree.physics_frame
	return done.call()


func _strike(element := &"") -> void:
	var info := DamageInfo.make(2, 0.0, player, element)
	info.team = player.hurtbox.team
	boss.hurtbox.receive(info)
	await tree.create_timer(0.3).timeout


func _risen() -> bool:
	return boss.state == Amaru.State.RISE and boss.body.position.y > -0.1


func test_risen_only_the_hook_counts() -> void:
	await _start()
	assert_true(await _until(_risen, 8.0), "asoma")
	var health := boss.health.current
	await _strike()
	assert_eq(boss.health.current, health, "asomada, la espada rebota")
	await _strike(Hook.ELEMENT)
	assert_true(await _until(func() -> bool: return boss.state == Amaru.State.STUCK, 2.0), "el gancho la tira al piso")
	var gap := (boss.global_position - player.global_position) * Vector3(1, 0, 1)
	assert_true(gap.length() < boss.yank_gap + 0.6, "junto al player (%.1f m)" % gap.length())
	health = boss.health.current
	await _strike()
	assert_eq(boss.health.current, health - 2, "tirada, la espada le pega")
	assert_true(await _until(func() -> bool: return boss.state == Amaru.State.UNDER, 8.0), "vuelve a un charco y se hunde")
	tree.root.get_node(^"GameState").reset()


func test_the_real_hookshot_pulls_her_out() -> void:
	await _start()
	var state: Node = tree.root.get_node(^"GameState")
	state.give(Items.get_item(&"hookshot"))
	state.assign_button(0, &"hookshot")
	assert_true(await _until(_risen, 8.0), "asoma")
	var pool := boss.global_position
	player.global_position = Vector3(pool.x, 0.2, pool.z + (4.0 if pool.z < 6.0 else -4.0))
	player.velocity = Vector3.ZERO
	await tree.physics_frame
	player.targeting.set_target(boss)
	var press := InputEventAction.new()
	press.action = &"item_1"
	press.pressed = true
	Input.parse_input_event(press)
	await tree.physics_frame
	var release := InputEventAction.new()
	release.action = &"item_1"
	Input.parse_input_event(release)
	assert_true(await _until(func() -> bool: return boss.state in [Amaru.State.LUNGE, Amaru.State.STUCK], 2.0), "la cadena le pega y la arranca")
	player.targeting.clear()
	state.reset()


func test_at_half_health_the_tail_sweeps_and_a_jump_clears_it() -> void:
	await _start()
	boss.health.current = boss.health.max_health / 2
	assert_true(await _until(func() -> bool: return boss._sweeping, 12.0), "barre con la cola")
	var health := player.health.current
	player.global_position = boss.tail.global_position + Vector3(0, 0.65, -2.5).rotated(Vector3.UP, boss._sweep_from + boss._swept + 1.8)
	player.velocity = Vector3.ZERO
	_hurtable = true
	await _until(func() -> bool: return not boss._sweeping, 4.0)
	_hurtable = false
	assert_true(player.health.current < health, "parado en el piso, la cola le pega")
	assert_true(await _until(func() -> bool: return boss._sweeping, 14.0), "barre otra vez")
	health = player.health.current
	_hurtable = true
	while boss._sweeping:
		player.global_position = boss.tail.global_position + Vector3(0, 2.2, -2.5).rotated(Vector3.UP, boss._sweep_from + boss._swept + 0.3)
		player.velocity = Vector3.ZERO
		await tree.physics_frame
	_hurtable = false
	assert_eq(player.health.current, health, "en el aire, la cola pasa por abajo")
	tree.root.get_node(^"GameState").reset()


func test_beaten_she_leaves_the_heart_container() -> void:
	await _start()
	assert_true(await _until(_risen, 8.0), "asoma")
	await _strike(Hook.ELEMENT)
	assert_true(await _until(func() -> bool: return boss.state == Amaru.State.STUCK, 2.0), "tirada")
	boss.health.current = 2
	await _strike()
	assert_true(boss.is_dead, "muere")
	assert_true(await _until(func() -> bool: return fight.reward.is_inside_tree(), 4.0), "aparece el contenedor")
	assert_eq(tree.root.get_node(^"GameState").get_flag(&"tt_boss_defeated"), true, "y queda vencida")
	tree.root.get_node(^"GameState").reset()
