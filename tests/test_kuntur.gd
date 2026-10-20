extends "res://tests/test_case.gd"
## Los cóndores de la Cumbre (D4): el Kuntur joven (sub-jefe, sin escudo) se clava en la nieve tras la picada y una
## flecha lo voltea mientras bate las alas; el Apu Kuntur (jefe) cae con sus plumas devueltas y, con media vida,
## enciende los soles y se posa: el rayo devuelto lo encandila.

const LEVEL := "res://levels/cumbre.tscn"
const ORB := preload("res://src/entities/projectile.tscn")

var tree: SceneTree
var level: Node
var player: PlayerCharacter
var state: Node
var kuntur: Kuntur


func _start(fight: NodePath, at: Vector3, shield := false) -> void:
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
	kuntur = level.get_node(fight).get_child(1) as Kuntur
	player.global_position = at
	player.velocity = Vector3.ZERO
	await _until(func() -> bool: return kuntur.state != Kuntur.State.IDLE, 8.0)


## Espera hasta que pasen `seconds` de reloj y también de juego: cargado, los cuadros vienen más lentos que el reloj.
func _until(done: Callable, seconds: float) -> bool:
	var until := Time.get_ticks_msec() + int(seconds * 1000)
	var frames := Engine.get_physics_frames() + int(seconds * Engine.physics_ticks_per_second)
	while Time.get_ticks_msec() < until or Engine.get_physics_frames() < frames:
		if done.call():
			return true
		player.health.current = player.health.max_health
		await tree.physics_frame
	return done.call()


func _strike(amount := 2) -> void:
	var info := DamageInfo.make(amount, 0.0, player)
	info.team = player.hurtbox.team
	kuntur.hurtbox.receive(info)
	await tree.create_timer(0.3).timeout


## Un proyectil del player: una flecha o, con `shooter`, algo que tiró otro y devolvió el escudo.
func _shoot(shooter: Node3D = null) -> void:
	var projectile := ORB.instantiate() as Projectile
	projectile.shooter = shooter
	var info := DamageInfo.make(1, 0.0, projectile)
	info.team = player.hurtbox.team
	kuntur.hurtbox.receive(info)
	projectile.free()
	await tree.create_timer(0.3).timeout


func test_the_young_condor_bounces_flying_and_gets_stuck_after_a_dive() -> void:
	await _start(^"PisoBase/KunturFight", Vector3(24, 0.2, 9))
	assert_true(kuntur is Kuntur and not kuntur.apu, "el sub-jefe del Nido es el Kuntur joven")
	var health := kuntur.health.current
	await _strike()
	assert_eq(kuntur.health.current, health, "volando, la espada rebota")
	assert_true(await _until(func() -> bool: return kuntur.state == Kuntur.State.STUCK, 14.0), "se tira en picada y queda clavado")
	assert_true(kuntur.arena.grow(0.01).has_point(Vector2(kuntur.global_position.x, kuntur.global_position.z)), "dentro de la sala")
	await _strike()
	assert_eq(kuntur.health.current, health - 2, "clavado, la espada le pega")
	state.reset()


func test_an_arrow_while_the_young_condor_flaps_knocks_it_down() -> void:
	await _start(^"PisoBase/KunturFight", Vector3(24, 0.2, 9))
	kuntur._attacks = 2
	assert_true(await _until(func() -> bool: return kuntur.state == Kuntur.State.GUST and kuntur._push > 0.0, 10.0), "se posa a batir las alas")
	var before := player.global_position
	await tree.create_timer(0.4).timeout
	assert_true(player.global_position.distance_to(before) > 0.5, "la ráfaga empuja al player")
	await _shoot()
	assert_eq(kuntur.state, Kuntur.State.DOWN, "una flecha lo voltea")
	var health := kuntur.health.current
	await _strike()
	assert_eq(kuntur.health.current, health - 2, "volteado, la espada le pega")
	state.reset()


func test_the_apu_drops_with_a_returned_feather_and_shrugs_off_arrows() -> void:
	await _start(^"PisoCima/BossFight", Vector3(40, 16.2, 24), true)
	assert_true(kuntur.apu, "el jefe de la Cima es el Apu Kuntur")
	assert_true(await _until(func() -> bool: return kuntur.state == Kuntur.State.VOLLEY, 10.0), "baja a tirar plumas")
	assert_true(await _until(func() -> bool: return level.find_children("*", "Projectile", false, false).size() >= 3, 3.0), "tira un abanico de plumas")
	for feather in level.find_children("*", "Projectile", false, false):
		feather.free()
	await _shoot()
	assert_true(kuntur.state != Kuntur.State.DOWN, "una flecha le rebota")
	await _shoot(kuntur)
	assert_eq(kuntur.state, Kuntur.State.DOWN, "una pluma devuelta lo voltea")
	var health := kuntur.health.current
	await _strike()
	assert_eq(kuntur.health.current, health - 2, "volteado, la espada le pega")
	state.reset()


func test_at_half_health_the_apu_lights_the_suns_and_a_reflected_ray_blinds_it_perched() -> void:
	await _start(^"PisoCima/BossFight", Vector3(40, 16.2, 24), true)
	var beam := level.get_node(^"PisoCima/SunWest/Beam") as LightBeam
	assert_true(not beam.visible, "los soles empiezan apagados")
	kuntur.health.current = kuntur.health.max_health / 2
	assert_true(await _until(func() -> bool: return beam.visible and not beam.segments.is_empty(), 12.0), "con media vida enciende los soles")
	kuntur._attacks = 2
	assert_true(await _until(func() -> bool: return kuntur.state == Kuntur.State.PERCH and kuntur.light_catch.collision_layer == 1, 12.0), "se posa en el centro y el haz lo puede tocar")
	kuntur.light_catch.receive_light()
	assert_eq(kuntur.state, Kuntur.State.DOWN, "el rayo lo encandila y lo voltea")
	state.reset()


func test_the_shield_sends_the_west_sun_into_the_perched_apu() -> void:
	await _start(^"PisoCima/BossFight", Vector3(37, 16.25, 18), true)
	kuntur.health.current = kuntur.health.max_health / 2
	kuntur._attacks = 2
	assert_true(await _until(func() -> bool: return kuntur.state == Kuntur.State.PERCH and kuntur.light_catch.collision_layer == 1, 20.0), "se posa")
	player.global_position = Vector3(37, 16.25, 18)
	player.velocity = Vector3.ZERO
	await tree.physics_frame
	var facing := (Vector3(-1, 0, 0) + (kuntur.global_position - player.global_position).normalized() * Vector3(1, 0, 1)).normalized()
	player.model.look_at(player.model.global_position - facing, Vector3.UP)
	hold_block(player, true)
	use_gamepad()
	assert_true(await _until(func() -> bool: return kuntur.state == Kuntur.State.DOWN, 3.0), "el escudo le manda el sol y lo voltea")
	hold_block(player, false)
	state.reset()


## Las alas aletean con los clips de %Wings y al morir quedan quietas mientras el cuerpo se aplasta y desaparece.
func test_the_wings_flap_until_it_dies() -> void:
	tree = Engine.get_main_loop() as SceneTree
	var bird := (load("res://src/entities/kuntur/apu_kuntur.tscn") as PackedScene).instantiate() as Kuntur
	tree.root.add_child(bird)
	var wing := bird.get_node(^"Body/WingLeft") as Node3D
	var seen := {}
	for i in 20:
		await tree.process_frame
		seen[snappedf(wing.rotation.z, 0.05)] = true
	assert_true(seen.size() > 3, "las alas se mueven (%d poses)" % seen.size())
	assert_true(is_equal_approx((bird.get_node(^"Body/WingRight") as Node3D).rotation.z, -wing.rotation.z), "las dos alas van parejas")
	var before := bird.body.scale
	bird._die()
	var still := wing.rotation.z
	await tree.create_timer(1.0).timeout
	assert_eq(wing.rotation.z, still, "muerto, las alas quedan quietas")
	assert_true(not bird.body.visible, "el cuerpo desaparece")
	assert_true(bird.body.scale.y < before.y * 0.2 and bird.body.scale.x > before.x, "aplastado sobre su escala propia")
	bird.free()
