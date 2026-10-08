extends "res://tests/test_case.gd"

const T := EntityConfig.Team


func test_health_damage_and_invulnerability() -> void:
	var health := Health.new()
	health.max_health = 8
	health.invulnerability_time = 0.5
	health._ready()
	var died := [false]
	health.died.connect(func() -> void: died[0] = true)
	assert_eq(health.damage(3), true)
	assert_eq(health.current, 5)
	assert_eq(health.damage(3), false, "invulnerable")
	health._physics_process(0.6)
	assert_eq(health.damage(10), true)
	assert_eq(health.current, 0)
	assert_eq(died[0], true)
	health.heal(20)
	assert_eq(health.current, 8)
	health.free()


func test_health_dies_once() -> void:
	var health := Health.new()
	health.max_health = 4
	health.invulnerability_time = 0.0
	health._ready()
	var deaths := [0]
	health.died.connect(func() -> void: deaths[0] += 1)
	health.damage(4)
	assert_eq(health.damage(4), false, "muerto no recibe daño")
	assert_eq(deaths[0], 1)
	health.free()


func test_hitbox_hits_each_hurtbox_once_per_attack() -> void:
	var hitbox := Hitbox.new()
	hitbox.team = T.PLAYER
	hitbox.damage_factory = func() -> DamageInfo:
		var info := DamageInfo.new()
		info.amount = 2
		info.knockback = 10.0
		return info
	var attack := AttackData.new()
	attack.damage_multiplier = 1.5
	attack.knockback_multiplier = 0.5
	hitbox.active_attack = attack
	var enemy := Hurtbox.new()
	enemy.team = T.ENEMY
	var ally := Hurtbox.new()
	ally.team = T.PLAYER
	var received: Array[DamageInfo] = []
	enemy.hit.connect(func(info: DamageInfo) -> void: received.append(info))
	ally.hit.connect(func(info: DamageInfo) -> void: received.append(info))

	hitbox._on_area_entered(enemy)
	hitbox._on_area_entered(enemy)
	hitbox._on_area_entered(ally)
	assert_eq(received.size(), 1)
	assert_eq(received[0].amount, 3)
	assert_eq(received[0].knockback, 5.0)
	assert_eq(received[0].team, T.PLAYER)

	hitbox.active_attack = attack
	hitbox._on_area_entered(enemy)
	assert_eq(received.size(), 2, "un swing nuevo vuelve a pegar")
	for node in [hitbox, enemy, ally]:
		node.free()


func test_attack_runner_window() -> void:
	var hitbox := Hitbox.new()
	var runner := AttackRunner.new()
	runner.hitboxes = { &"front": hitbox }
	var attack := AttackData.new()
	attack.active_from = 0.3
	attack.active_to = 0.6
	runner.start(attack, 1.0)
	runner._physics_process(0.2)
	assert_eq(hitbox.active_attack, null, "antes del tramo")
	runner._physics_process(0.2)
	assert_eq(hitbox.active_attack, attack, "en el tramo")
	runner._physics_process(0.3)
	assert_eq(hitbox.active_attack, null, "después del tramo")
	runner._physics_process(0.4)
	assert_eq(runner.is_running(), false)

	runner.start(attack, 1.0)
	runner._physics_process(0.4)
	runner.stop()
	assert_eq(hitbox.active_attack, null, "stop apaga la hitbox")
	runner.free()
	hitbox.free()


func test_entity_config() -> void:
	var skeleton := load("res://data/entities/skeleton.tres") as EntityConfig
	assert_eq(skeleton.has(EntityConfig.Feature.TARGETABLE), true)
	assert_eq(skeleton.has(EntityConfig.Feature.REFLECTS), false)
	var node := Node3D.new()
	skeleton.apply_to(node)
	assert_eq(node.is_in_group(&"targetable"), true)
	assert_eq(node.is_in_group(&"pushable"), true)
	var info := skeleton.make_damage(node)
	assert_eq(info.team, T.ENEMY)
	assert_eq(info.amount, skeleton.attack_damage)
	node.free()
	for path in ["res://data/entities/player.tres", "res://data/entities/test_box.tres"]:
		assert_true(load(path) is EntityConfig, path)


func test_attacks_load() -> void:
	for attack_name in ["sword_slash", "shield_thrust", "skeleton_slash"]:
		var attack := load("res://data/attacks/%s.tres" % attack_name) as AttackData
		assert_true(attack != null, attack_name)
		if attack:
			assert_true(attack.active_from < attack.active_to, attack_name)
			assert_true(String(attack.animation).begins_with("CombatMelee/"), attack_name)
