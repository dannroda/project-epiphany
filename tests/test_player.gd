extends "res://tests/test_case.gd"

const LEVEL := "res://levels/test.tscn"


func _load_level() -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.get_node(^"GameState").reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	var enemy := tree.get_first_node_in_group(&"enemies") as Enemy
	for i in 300:
		if player.movement_state.get_active_state().name == &"Idle":
			break
		await tree.physics_frame
	return [tree, player, enemy]


func test_sword_hits_skeleton_once() -> void:
	var setup: Array = await _load_level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var enemy: Enemy = setup[2]
	assert_eq(player.movement_state.get_active_state().name, &"Idle", "terminó de aparecer")
	assert_eq(player.equipment.weapon.id, &"sword_basic")
	var start_health := enemy.health.current
	player.global_position = enemy.global_position - Vector3(0, 0, 1.2)
	player.model.rotation = Vector3.ZERO
	await tree.physics_frame

	var press := InputEventAction.new()
	press.action = &"attack"
	press.pressed = true
	Input.parse_input_event(press)
	await tree.physics_frame
	var release := InputEventAction.new()
	release.action = &"attack"
	Input.parse_input_event(release)
	for i in 120:
		await tree.physics_frame

	var damage := Items.get_item(&"sword_basic").damage
	assert_eq(enemy.health.current, start_health - damage, "un solo golpe")
	assert_eq(player.attack_runner.is_running(), false, "la hitbox quedó apagada")


func test_equipment_follows_game_state() -> void:
	var setup: Array = await _load_level()
	var player: PlayerCharacter = setup[1]
	var game_state: Node = setup[0].root.get_node(^"GameState")
	assert_true(player.equipment.shield_on_back != null)
	game_state.equip(Items.get_item(&"shield_mirror"))
	assert_eq(player.equipment.shield_on_back.scene_file_path, "res://assets/items/shield/shield_mirror.tscn")
	assert_eq(player.equipment.shield_in_hand.visible, false)
	game_state.reset()


func _enemy_hit(player: PlayerCharacter, enemy: Enemy, amount: int) -> void:
	var info := enemy.config.make_damage(enemy)
	info.amount = amount
	player.hurtbox.receive(info)


func test_hurt_knockback_and_invulnerability() -> void:
	var setup: Array = await _load_level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var enemy: Enemy = setup[2]
	player.global_position = enemy.global_position - Vector3(0, 0, 1.5)
	await tree.physics_frame
	var start := player.health.current
	_enemy_hit(player, enemy, 2)
	await tree.physics_frame
	assert_eq(player.health.current, start - 2)
	assert_eq(player.movement_state.get_active_state().name, &"Hurt")
	assert_true(player.velocity.z < 0.0, "retrocede alejándose del esqueleto")
	assert_true(player.health.is_invulnerable())
	_enemy_hit(player, enemy, 2)
	assert_eq(player.health.current, start - 2, "invulnerable")
	for i in 30:
		await tree.physics_frame
	assert_eq(player.movement_state.get_active_state().name, &"Idle", "vuelve a Idle")


func test_armor_reduces_damage() -> void:
	var setup: Array = await _load_level()
	var player: PlayerCharacter = setup[1]
	var enemy: Enemy = setup[2]
	var game_state: Node = setup[0].root.get_node(^"GameState")
	game_state.equip(Items.get_item(&"armor_chainmail"))
	var start := player.health.current
	_enemy_hit(player, enemy, 4)
	assert_eq(player.health.current, start - 3, "−25 %")
	game_state.reset()


func _block(player: PlayerCharacter, on: bool) -> void:
	player.movement_state.blackboard.set_var("is_blocking", on)


func test_block_from_front_only() -> void:
	var setup: Array = await _load_level()
	var player: PlayerCharacter = setup[1]
	var enemy: Enemy = setup[2]
	enemy.bt_player.active = false
	player.global_position = enemy.global_position - Vector3(0, 0, 1.5)
	player.model.rotation = Vector3.ZERO
	_block(player, true)
	var start := player.health.current
	_enemy_hit(player, enemy, 2)
	assert_eq(player.health.current, start, "de frente: bloqueado")
	player.model.rotation = Vector3(0, PI, 0)
	_enemy_hit(player, enemy, 2)
	assert_eq(player.health.current, start - 2, "de espaldas: recibe el golpe")
	_block(player, false)


func test_shield_thrust_stuns() -> void:
	var setup: Array = await _load_level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var enemy: Enemy = setup[2]
	player.global_position = enemy.global_position - Vector3(0, 0, 1.2)
	player.model.rotation = Vector3.ZERO
	_block(player, true)
	var press := InputEventAction.new()
	press.action = &"attack"
	press.pressed = true
	Input.parse_input_event(press)
	await tree.physics_frame
	var release := InputEventAction.new()
	release.action = &"attack"
	Input.parse_input_event(release)
	var stunned := false
	for i in 90:
		await tree.physics_frame
		if enemy.bt_player.blackboard.get_var("stunned", false, false):
			stunned = true
			break
	assert_true(stunned, "el golpe de escudo aturde")
	_block(player, false)
