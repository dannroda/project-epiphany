extends "res://tests/test_case.gd"
## El jefe final en co-op (11.214): elige objetivo en cada decisión, cambia solo si otro está bastante más cerca,
## sigue a quien le pegó al ojo aturdido y no ataca si no queda nadie en la arena.

const BOSS := preload("res://src/entities/boss/boss.tscn")
const PAD_1 := 0
const PAD_2 := 1

var tree: SceneTree
var players: Node
var boss: Boss
var first: PlayerCharacter
var second: PlayerCharacter


func _start() -> void:
	tree = Engine.get_main_loop() as SceneTree
	players = tree.root.get_node(^"Players")
	tree.root.get_node(^"GameState").reset()
	tree.change_scene_to_file("res://levels/test/test_rooms.tscn")
	await tree.scene_changed
	for i in 4:
		await tree.physics_frame
	tree.current_scene.get_node(^"Skeleton").free()
	players.lead_pad = PAD_1
	second = players.join(PAD_2)
	for i in 3:
		await tree.physics_frame
	first = players.lead()
	boss = BOSS.instantiate() as Boss
	tree.current_scene.add_child(boss)


func _done() -> void:
	boss.free()
	for slot in players.guests.keys():
		players.leave(slot)
	players.lead_pad = -1
	await tree.process_frame
	tree.root.get_node(^"GameState").reset()


func _at(player: PlayerCharacter, distance: float) -> void:
	player.global_position = Vector3(boss.eye.global_position.x + distance, player.global_position.y, boss.eye.global_position.z)


func test_it_keeps_its_target_unless_another_is_much_closer() -> void:
	await _start()
	_at(first, 4.0)
	_at(second, 8.0)
	assert_eq(boss.pick_target(), first, "empieza por el más cercano")
	_at(second, 2.0)
	assert_eq(boss.pick_target(), first, "2 m más cerca no alcanza para cambiar")
	_at(second, 0.5)
	assert_eq(boss.pick_target(), second, "3.5 m más cerca, cambia")
	await _done()


func test_whoever_hits_the_stunned_eye_is_the_next_target() -> void:
	await _start()
	_at(first, 2.0)
	_at(second, 9.0)
	boss.pick_target()
	assert_eq(Boss._player_from(second.get_node(^"Hurtbox")), second, "un golpe de su espada es suyo")
	boss._aggro = second
	assert_eq(boss.pick_target(), second, "quien pegó al ojo aturdido gana la próxima")
	assert_eq(boss.pick_target(), first, "la decisión siguiente vuelve al que está bastante más cerca")
	await _done()


func test_the_second_hand_goes_for_the_other_player() -> void:
	await _start()
	_at(first, 2.0)
	_at(second, 6.0)
	boss.pick_target()
	assert_eq(boss._other_target(), second, "la mano del combo va al otro")
	second.health.damage(second.health.current)
	await tree.physics_frame
	assert_eq(boss._other_target(), first, "solo con uno vivo, las dos van a él")
	await _done()


func test_with_nobody_in_the_arena_it_does_not_attack() -> void:
	await _start()
	boss.arena = Rect2(boss.eye.global_position.x + 100.0, boss.eye.global_position.z + 100.0, 10.0, 10.0)
	assert_eq(boss.pick_target(), null, "nadie en la arena")
	assert_true(not boss.choose_attack(1), "no elige ataque")
	await _done()


func test_a_dead_target_hands_the_next_attack_to_the_other() -> void:
	await _start()
	_at(first, 2.0)
	_at(second, 9.0)
	assert_eq(boss.pick_target(), first)
	first.health.damage(first.health.current)
	await tree.physics_frame
	assert_eq(boss.pick_target(), second, "muerto el primero, va al otro aunque esté lejos")
	await _done()
