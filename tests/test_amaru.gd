extends "res://tests/test_case.gd"
## El Amaru (sub-jefe de D3): asoma por sus charcos, marca una línea y se lanza; solo tirado sobre la totora le pega
## algo. Con la mitad de la vida escupe antes de lanzarse. Vencido, abre la cámara del gancho.

const LEVEL := "res://levels/totora.tscn"

var tree: SceneTree
var level: Node
var player: PlayerCharacter
var amaru: Amaru
var fight: ArenaFight


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
	fight = level.get_node(^"PisoBajo/AmaruFight") as ArenaFight
	amaru = fight.get_node(^"Amaru") as Amaru
	player.global_position = Vector3(24, 0.2, 10)
	player.velocity = Vector3.ZERO
	await _until(func() -> bool: return amaru.state != Amaru.State.IDLE, 8.0)


## Espera algo, con el player siempre sano: los lanzazos le pegan.
func _until(done: Callable, seconds: float) -> bool:
	var until := Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < until:
		if done.call():
			return true
		player.health.current = player.health.max_health
		await tree.physics_frame
	return done.call()


func _strike(amount := 2) -> void:
	var info := DamageInfo.make(amount, 0.0, player)
	info.team = player.hurtbox.team
	amaru.hurtbox.receive(info)
	await tree.create_timer(0.3).timeout


func test_it_rises_from_a_pool_and_the_sword_bounces() -> void:
	await _start()
	assert_true(amaru.state != Amaru.State.IDLE, "al entrar al Pozo arranca la pelea")
	assert_true(await _until(func() -> bool: return amaru.state == Amaru.State.AIM, 8.0), "asoma y apunta")
	var near := amaru.pools.any(func(pool: Node3D) -> bool: return (pool.global_position - amaru.global_position) * Vector3(1, 0, 1) == Vector3.ZERO)
	assert_true(near, "asoma por un charco")
	assert_true(amaru.aim_line.visible, "marca la línea")
	var health := amaru.health.current
	await _strike()
	assert_eq(amaru.health.current, health, "asomada, la espada rebota")
	tree.root.get_node(^"GameState").reset()


func test_the_lunge_stays_in_the_room_and_leaves_it_exposed() -> void:
	await _start()
	assert_true(await _until(func() -> bool: return amaru.state == Amaru.State.STUCK, 12.0), "se lanza y queda tirada")
	var at := Vector2(amaru.global_position.x, amaru.global_position.z)
	assert_true(amaru.arena.grow(0.01).has_point(at), "cae dentro de la sala (%s)" % at)
	var health := amaru.health.current
	await _strike()
	assert_eq(amaru.health.current, health - 2, "tirada, la espada le pega")
	assert_true(await _until(func() -> bool: return amaru.state == Amaru.State.UNDER, 8.0), "vuelve a un charco y se hunde")
	tree.root.get_node(^"GameState").reset()


func test_at_half_health_it_spits_before_lunging() -> void:
	await _start()
	amaru.health.current = amaru.health.max_health / 2
	var spat := await _until(func() -> bool: return _orbs() > 0, 12.0)
	assert_true(spat, "escupe")
	tree.root.get_node(^"GameState").reset()


func _orbs() -> int:
	return level.find_children("*", "Projectile", false, false).size() if is_instance_valid(level) else 0


func test_beaten_it_opens_the_hookshot_room() -> void:
	await _start()
	var door := level.get_node(^"PisoBajo/GanchoDoor") as Door
	assert_true(not door.is_open, "pelea con la puerta cerrada")
	assert_true(await _until(func() -> bool: return amaru.state == Amaru.State.STUCK, 12.0), "queda tirada")
	amaru.health.current = 2
	await _strike()
	assert_true(amaru.is_dead, "muere")
	assert_true(await _until(func() -> bool: return door.is_open, 4.0), "abre la cámara del gancho")
	assert_eq(tree.root.get_node(^"GameState").get_flag(&"tt_amaru_defeated"), true, "y queda vencida")
	tree.root.get_node(^"GameState").reset()
