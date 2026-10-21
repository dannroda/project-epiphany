extends "res://tests/test_case.gd"

const LEVEL := "res://levels/test/test.tscn"


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


func _frames(tree: SceneTree, count: int) -> void:
	for i in count:
		await tree.physics_frame


func test_chases_and_hits_the_player() -> void:
	var setup: Array = await _load_level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var enemy: Enemy = setup[2]
	player.global_position = enemy.global_position - Vector3(0, 0, 5)
	var start_distance := player.global_position.distance_to(enemy.global_position)
	var start_health := player.health.current
	var closest := start_distance
	for i in 400:
		await tree.physics_frame
		closest = minf(closest, player.global_position.distance_to(enemy.global_position))
		if player.health.current < start_health:
			break
	assert_true(closest < start_distance - 2.0, "se acercó (%.1f → %.1f)" % [start_distance, closest])
	assert_true(player.health.current < start_health, "le pegó al player")


func test_hit_during_windup_cancels_attack() -> void:
	var setup: Array = await _load_level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var enemy: Enemy = setup[2]
	player.global_position = enemy.global_position - Vector3(0, 0, 1.2)
	var attacking := false
	for i in 120:
		await tree.physics_frame
		if enemy.anim_player.current_animation == &"CombatMelee/Melee_1H_Attack_Chop":
			attacking = true
			break
	assert_true(attacking, "empezó el ataque")
	var info := player.config.make_damage(player)
	enemy.hurtbox.receive(info)
	await _frames(tree, 3)
	assert_eq(enemy.attack_runner.is_running(), false, "la hitbox se apagó")
	assert_eq(enemy.hitbox.active_attack, null)


func test_windup_glows_and_recovery_leaves_an_opening() -> void:
	var setup: Array = await _load_level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var enemy: Enemy = setup[2]
	player.global_position = enemy.global_position - Vector3(0, 0, 1.2)
	player.health.make_invulnerable(10.0)
	var glow := 0.0
	for i in 120:
		await tree.physics_frame
		if enemy.anim_player.current_animation == &"CombatMelee/Melee_1H_Attack_Chop":
			break
	for i in 30:
		await tree.physics_frame
		glow = maxf(glow, enemy.flash.flash_amount())
	assert_true(glow > 0.3, "brilla mientras carga (%.2f)" % glow)
	var struck := false
	for i in 120:
		await tree.physics_frame
		if enemy.attack_runner.is_running():
			struck = true
		elif struck:
			break
	assert_true(struck, "soltó el golpe")
	var still := true
	var start := enemy.global_position
	for i in 12:
		await tree.physics_frame
		still = still and enemy.global_position.distance_to(start) < 0.05 and not enemy.attack_runner.is_running()
	assert_true(still, "queda quieto un momento después del golpe")


func test_death_releases_lock_on() -> void:
	var setup: Array = await _load_level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var enemy: Enemy = setup[2]
	var defeated := [false]
	enemy.defeated.connect(func(_e: Enemy) -> void: defeated[0] = true)
	enemy.health.invulnerability_time = 0.0
	enemy.health.damage(100)
	await _frames(tree, 2)
	assert_eq(defeated[0], true)
	assert_eq(enemy.is_in_group(&"targetable"), false)
	await _frames(tree, 150)
	assert_eq(enemy.bt_player.active, false, "terminó de morir")
	assert_true(is_instance_valid(enemy), "el cuerpo queda un rato")
	await tree.create_timer(enemy.corpse_time + enemy.sink_time + 0.3).timeout
	assert_true(not is_instance_valid(enemy), "y después se va")


func test_enemies_do_not_spawn_inside_walls() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	for path in ["res://levels/overworld.tscn", "res://levels/templo.tscn"]:
		tree.root.get_node(^"GameState").reset()
		tree.change_scene_to_file(path)
		await tree.scene_changed
		await tree.physics_frame
		for enemy: CollisionObject3D in tree.get_nodes_in_group(&"enemies"):
			var shape := enemy.get_node_or_null(^"CollisionShape3D") as CollisionShape3D
			if shape == null:
				continue
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = shape.shape
			query.transform = shape.global_transform.translated(Vector3.UP * 0.1)
			query.collision_mask = 1
			query.exclude = [enemy.get_rid()]
			var hits := enemy.get_world_3d().direct_space_state.intersect_shape(query)
			var walls := hits.filter(func(hit: Dictionary) -> bool: return not hit.collider is CharacterBody3D)
			assert_true(walls.is_empty(), "%s en %s está encimado con %s" % [enemy.name, path.get_file(), walls.map(func(hit: Dictionary) -> String: return str(hit.collider))])


func test_meadow_skeletons_reach_the_player() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.get_node(^"GameState").reset()
	tree.change_scene_to_file("res://levels/overworld.tscn")
	await tree.scene_changed
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	player.health.make_invulnerable(999.0)
	player.global_position = Vector3(-42, 0.1, -2)
	var until := Time.get_ticks_msec() + 6000
	var enemies := [^"Skeleton1", ^"Skeleton2", ^"Skeleton3"].map(func(path: NodePath) -> Node: return tree.current_scene.get_node(path))
	var near := func() -> bool:
		return enemies.all(func(enemy: Enemy) -> bool: return enemy.global_position.distance_to(player.global_position) <= enemy.config.attack_range + 0.5)
	while Time.get_ticks_msec() < until and not near.call():
		await tree.physics_frame
	for enemy: Enemy in enemies:
		assert_true(enemy.global_position.distance_to(player.global_position) <= enemy.config.attack_range + 0.5, "%s llega al player (quedó en %s)" % [enemy.name, enemy.global_position])


## 11.9: con la navmesh pegada al piso, rodea una columna que lo separa del player sin trabarse en las esquinas. La
## columna se agrega en el lugar abierto del templo más cerca de la entrada y la navmesh se vuelve a hornear con la misma configuración.
func test_an_enemy_goes_around_a_column() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.get_node(^"GameState").reset()
	tree.change_scene_to_file("res://levels/templo.tscn")
	await tree.scene_changed
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	player.health.make_invulnerable(999.0)
	var grid := tree.current_scene.get_node(^"Planta/GridMap") as GridMap
	var library := grid.mesh_library
	var open := func(cell: Vector3i) -> bool:
		for dx in range(-2, 3):
			for dz in range(-3, 4):
				var item := grid.get_cell_item(cell + Vector3i(dx, 0, dz))
				if item < 0 or not library.get_item_name(item).begins_with("Piso"):
					return false
		return true
	var spot := Vector3.INF
	for cell in grid.get_used_cells():
		var at := grid.to_global(grid.map_to_local(cell))
		if at.distance_to(player.global_position) < spot.distance_to(player.global_position) and open.call(cell):
			spot = at
	assert_true(spot != Vector3.INF, "hay un lugar abierto en el templo")
	var column := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(2, 2.6, 2)
	shape.position.y = 1.3
	column.add_child(shape)
	column.add_to_group(&"navmesh_source")
	tree.current_scene.add_child(column)
	column.global_position = spot
	await tree.physics_frame
	WallTops.register()
	var region := tree.current_scene.get_node(^"NavigationRegion3D") as NavigationRegion3D
	region.navigation_mesh = region.navigation_mesh.duplicate()
	region.bake_navigation_mesh(false)
	var enemy := (load("res://src/entities/guerreros/skeleton_templo.tscn") as PackedScene).instantiate() as Enemy
	tree.current_scene.add_child(enemy)
	enemy.global_position = spot + Vector3(0.4, 0, -3.0)
	player.global_position = spot + Vector3(3.0, 0.1, -3.0)
	var blackboard := enemy.bt_player.blackboard
	for i in 120:
		if blackboard.get_var(&"target", null, false) == player:
			break
		await tree.physics_frame
	assert_eq(blackboard.get_var(&"target", null, false), player, "lo ve al costado de la columna")
	player.global_position = spot + Vector3(-0.4, 0.1, 3.0)
	var until := Time.get_ticks_msec() + 8000
	var reach := enemy.config.attack_range + 0.5
	while Time.get_ticks_msec() < until and enemy.global_position.distance_to(player.global_position) > reach:
		await tree.physics_frame
	assert_true(enemy.global_position.distance_to(player.global_position) <= reach, "llega al player rodeando la columna (quedó en %s, player en %s)" % [enemy.global_position - spot, player.global_position - spot])
	tree.root.get_node(^"GameState").reset()


func test_an_enemy_that_sees_nobody_wanders_near_its_spot() -> void:
	var setup: Array = await _load_level()
	var tree: SceneTree = setup[0]
	var enemy: Enemy = setup[2]
	enemy.config = enemy.config.duplicate()
	enemy.config.vision_range = 0.0
	enemy.config.wander_pause = Vector2(0.2, 0.4)
	var home := enemy.global_position
	var farthest := 0.0
	var walked := false
	for i in 600:
		await tree.physics_frame
		var away := Vector2(enemy.global_position.x - home.x, enemy.global_position.z - home.z).length()
		farthest = maxf(farthest, away)
		walked = walked or enemy.anim_player.current_animation == &"MovementBasic/Walking_A"
	assert_true(farthest > 0.5, "deambula: se alejó %.2f m de donde empezó" % farthest)
	assert_true(farthest <= enemy.config.wander_radius + 0.6, "sin pasarse del radio (%.2f m)" % farthest)
	assert_true(walked, "camina, no corre")
	assert_true(enemy.desired_velocity.length() <= enemy.config.wander_speed + 0.01, "a paso de paseo")
	tree.root.get_node(^"GameState").reset()


func test_in_a_dungeon_room_the_chase_does_not_drop() -> void:
	var setup: Array = await _load_level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var enemy: Enemy = setup[2]
	var room := Room.new()
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(60, 8, 60)
	room.add_child(shape)
	tree.current_scene.add_child(room)
	room.global_position = enemy.global_position
	enemy._home = Vector3.INF
	player.global_position = enemy.global_position - Vector3(0, 0, 4)
	await _frames(tree, 20)
	var blackboard := enemy.bt_player.blackboard
	assert_eq(blackboard.get_var(&"target", null, false), player, "lo vio y lo persigue")
	enemy.config = enemy.config.duplicate()
	enemy.config.vision_range = 0.0
	await _frames(tree, 20)
	assert_eq(blackboard.get_var(&"target", null, false), player, "en la misma sala no lo suelta aunque no lo vea")
	room.free()
	enemy._home = Vector3.INF
	await _frames(tree, 20)
	assert_eq(blackboard.get_var(&"target", null, false), null, "fuera de una sala lo pierde")
	tree.root.get_node(^"GameState").reset()


func test_in_the_overworld_the_chase_lasts_while_the_player_stays_in_its_chase_region() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.get_node(^"GameState").reset()
	tree.change_scene_to_file("res://levels/overworld.tscn")
	await tree.scene_changed
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	player.health.make_invulnerable(999.0)
	var enemy := tree.current_scene.get_node(^"Skeleton1") as Enemy
	var chasing := func() -> bool: return enemy.bt_player.blackboard.get_var(&"target", null) == player
	player.global_position = Vector3(-42, 0.1, -2)
	var until := Time.get_ticks_msec() + 4000
	while Time.get_ticks_msec() < until and not chasing.call():
		await tree.physics_frame
	assert_true(chasing.call(), "ve al player y lo persigue (target %s)" % enemy.bt_player.blackboard.get_var(&"target", null))
	player.global_position = Vector3(-17, 0.1, -20)
	await _frames(tree, 30)
	assert_true(enemy.global_position.distance_to(player.global_position) > enemy.config.vision_range * 1.4, "el player quedó lejos")
	assert_true(chasing.call(), "lejos pero en la Pradera, lo sigue persiguiendo")
	player.global_position = Vector3(-60, 0.1, 15)
	await _frames(tree, 30)
	assert_true(chasing.call(), "en el Primer Claro también: comparte la persecución con la Pradera")
	player.global_position = Vector3(-30, 2.7, 15)
	await _frames(tree, 30)
	assert_true(not chasing.call(), "en la Arboleda lo suelta")
	tree.root.get_node(^"GameState").reset()


func test_hit_reaction_plays_and_clears_its_flag() -> void:
	var setup: Array = await _load_level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var enemy: Enemy = setup[2]
	player.global_position = enemy.global_position - Vector3(0, 0, 8)
	var info := DamageInfo.make(1, 0.0, player)
	enemy.hurtbox.receive(info)
	var played := false
	for i in 20:
		await tree.physics_frame
		played = played or enemy.anim_player.current_animation == &"General/Hit_A"
	assert_true(played, "el subárbol de reacciones pone Hit_A")
	for i in 120:
		if enemy.bt_player.blackboard.get_var(Enemy.BB_IS_HIT, true) == false:
			break
		await tree.physics_frame
	assert_eq(enemy.bt_player.blackboard.get_var(Enemy.BB_IS_HIT, true), false, "y apaga is_hit en el blackboard del enemigo")


func test_a_second_stun_plays_again() -> void:
	var setup: Array = await _load_level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var enemy: Enemy = setup[2]
	player.global_position = enemy.global_position - Vector3(0, 0, 8)
	for turn in 2:
		enemy.bt_player.blackboard.set_var(Enemy.BB_STUNNED, true)
		var played := false
		for i in 20:
			await tree.physics_frame
			played = played or enemy.anim_player.current_animation == &"General/Hit_B"
		assert_true(played, "aturdido %d: Hit_B" % (turn + 1))
		for i in 150:
			if enemy.bt_player.blackboard.get_var(Enemy.BB_STUNNED, true) == false:
				break
			await tree.physics_frame
		assert_eq(enemy.bt_player.blackboard.get_var(Enemy.BB_STUNNED, true), false, "aturdido %d se termina" % (turn + 1))
