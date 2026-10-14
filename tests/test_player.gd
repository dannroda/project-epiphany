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
	hold_block(player, on)


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


func _press(action: StringName) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	Input.parse_input_event(press)
	var release := InputEventAction.new()
	release.action = action
	Input.parse_input_event(release)


func _state(player: PlayerCharacter) -> StringName:
	return player.movement_state.get_active_state().name


func test_roll_iframes() -> void:
	var setup: Array = await _load_level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var enemy: Enemy = setup[2]
	enemy.bt_player.active = false
	var start := player.health.current
	_press(&"dodge")
	for i in 30:
		await tree.physics_frame
		if _state(player) == &"Dodging" and player.health.is_invulnerable():
			break
	assert_eq(_state(player), &"Dodging")
	_enemy_hit(player, enemy, 2)
	assert_eq(player.health.current, start, "i-frames")
	for i in 60:
		await tree.physics_frame
	assert_eq(_state(player), &"Idle")
	_enemy_hit(player, enemy, 2)
	assert_eq(player.health.current, start - 2, "después del roll sí recibe")


func test_roll_leaves_ghosts_that_fade() -> void:
	var setup: Array = await _load_level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	(setup[2] as Enemy).bt_player.active = false
	_press(&"dodge")
	await tree.create_timer(0.2).timeout
	var ghosts := tree.current_scene.find_children("*", "Afterimage", false, false)
	assert_true(ghosts.size() >= 2, "rodando deja fantasmas (%d)" % ghosts.size())
	if ghosts.is_empty():
		return
	var ghost := ghosts[0] as Afterimage
	assert_true(ghost.mesh.get_surface_count() > 0 and ghost.mesh.get_aabb().size.y > 0.5, "con la pose del player")
	assert_true(ghost.get_instance_shader_parameter(&"fade") < 1.0, "y se van desvaneciendo")
	await tree.create_timer(0.8).timeout
	assert_eq(tree.current_scene.find_children("*", "Afterimage", false, false).size(), 0, "hasta irse")


func test_roll_cancels_attack() -> void:
	var setup: Array = await _load_level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	setup[2].bt_player.active = false
	_press(&"attack")
	for i in 20:
		await tree.physics_frame
		if player.attack_runner.is_running():
			break
	assert_eq(_state(player), &"Attacking")
	_press(&"dodge")
	await tree.physics_frame
	await tree.physics_frame
	assert_eq(_state(player), &"Attacking", "en plena estocada no se corta")
	for i in 120:
		await tree.physics_frame
		if player.attack_runner.progress() >= player.current_attack().cancel_from:
			break
	_press(&"dodge")
	await tree.physics_frame
	await tree.physics_frame
	assert_eq(_state(player), &"Dodging")
	assert_eq(player.attack_runner.is_running(), false)
	assert_eq(player.hitbox.active_attack, null)


func test_attack_chains_in_cancel_window() -> void:
	var setup: Array = await _load_level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	setup[2].bt_player.active = false
	var entered := [0]
	player.movement_state.get_node(^"Attacking").entered.connect(func() -> void: entered[0] += 1)
	_press(&"attack")
	for i in 120:
		await tree.physics_frame
		if player.attack_runner.is_running():
			break
	var cancel_from := player.current_attack().cancel_from
	for i in 120:
		await tree.physics_frame
		if player.attack_runner.progress() >= cancel_from:
			break
	var progress := player.attack_runner.progress()
	_press(&"attack")
	for i in 5:
		await tree.physics_frame
	assert_eq(entered[0], 2, "el segundo golpe sale en cuanto se puede cortar")
	assert_true(progress < 0.75, "sin esperar el final de la animación (%.2f)" % progress)
	assert_true(player.attack_runner.progress() < 0.2, "el golpe nuevo arrancó de cero")


func test_attack_turns_to_target_and_steps_forward() -> void:
	var setup: Array = await _load_level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var enemy: Enemy = setup[2]
	enemy.bt_player.active = false
	player.global_position = enemy.global_position + Vector3(2.5, 0, 0)
	player.model.look_at(player.model.global_position + Vector3(1, 0, 0), Vector3.UP)
	await tree.physics_frame
	player.targeting.set_target(enemy)
	var start := player.global_position
	_press(&"attack")
	for i in 3:
		await tree.physics_frame
	var forward := player.model.global_basis.z
	assert_true(forward.dot(Vector3.LEFT) > 0.95, "mira al objetivo al arrancar (%s)" % forward)
	for i in 20:
		await tree.physics_frame
	assert_true(player.global_position.x < start.x - 0.15, "da un paso hacia el objetivo")
	player.targeting.clear()


func test_buffered_attack_after_attack() -> void:
	var setup: Array = await _load_level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	setup[2].bt_player.active = false
	var entered := [0]
	player.movement_state.get_node(^"Attacking").entered.connect(func() -> void: entered[0] += 1)
	_press(&"attack")
	for i in 300:
		await tree.physics_frame
		if _state(player) == &"Attacking" and player.attack_runner.progress() > 0.9:
			break
	_press(&"attack")
	for i in 120:
		await tree.physics_frame
		if entered[0] >= 2:
			break
	assert_eq(entered[0], 2, "el segundo ataque salió por el buffer")


func test_death_and_respawn() -> void:
	var setup: Array = await _load_level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	var enemy: Enemy = setup[2]
	var enemy_start := enemy.global_position
	player.global_position = enemy.global_position - Vector3(0, 0, 3)
	await tree.physics_frame
	_enemy_hit(player, enemy, 100)
	await tree.physics_frame
	assert_eq(_state(player), &"Dead")
	for i in 20:
		await tree.physics_frame
	assert_eq(enemy.bt_player.blackboard.get_var("target", null, false), null, "el esqueleto deja de verlo")
	var stack: Node = tree.root.get_node(^"MenuStack")
	for i in 300:
		if stack.top() is GameOver:
			break
		await tree.process_frame
	assert_true(stack.top() is GameOver, "aparece el game over")
	assert_eq(tree.paused, true, "con el mundo en pausa")
	(stack.top() as GameOver)._continue.pressed.emit()
	var respawned: PlayerCharacter = null
	for i in 400:
		await tree.physics_frame
		var current := tree.get_first_node_in_group(&"player") as PlayerCharacter
		if current and current != player and is_instance_valid(current) and current.is_inside_tree():
			respawned = current
			break
	assert_true(respawned != null, "reapareció")
	if respawned:
		await tree.physics_frame
		var spawn := SpawnPoint.find(tree, &"start")
		assert_true(respawned.global_position.distance_to(spawn.global_position) < 0.5, "en el spawn")
		assert_eq(respawned.health.current, respawned.health.max_health, "con la vida llena")
		var new_enemy := tree.get_first_node_in_group(&"enemies") as Enemy
		assert_true(new_enemy.global_position.distance_to(enemy_start) < 0.5, "el esqueleto volvió a su lugar")


func test_silhouette_only_on_the_player() -> void:
	var setup: Array = await _load_level()
	var player: PlayerCharacter = setup[1]
	var enemy: Enemy = setup[2]
	var shader := preload("res://src/feel/occluded_silhouette.gdshader")
	var player_meshes := player.get_node(^"ModelController/Visuals").find_children("*", "MeshInstance3D", true, false)
	assert_true(not player_meshes.is_empty())
	for mesh: MeshInstance3D in player_meshes:
		var silhouette := mesh.material_overlay.next_pass as ShaderMaterial
		assert_true(silhouette != null and silhouette.shader == shader, "%s tiene silueta detrás de paredes" % mesh.name)
	for mesh: MeshInstance3D in enemy.find_children("*", "MeshInstance3D", true, false):
		if mesh.material_overlay:
			assert_eq(mesh.material_overlay.next_pass, null, "los enemigos no")


func test_falling_keeps_the_player_upright() -> void:
	var setup: Array = await _load_level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	player.global_position += Vector3.UP * 6.0
	Input.action_press(&"move_right")
	var tilt := 0.0
	for i in 30:
		await tree.physics_frame
		tilt = maxf(tilt, player.model.global_basis.y.normalized().angle_to(Vector3.UP))
	Input.action_release(&"move_right")
	assert_true(player.velocity.y < -1.0, "está cayendo")
	assert_true(tilt < 0.05, "cae parado (inclinación %.2f rad)" % tilt)


func test_what_the_player_carries_has_the_silhouette() -> void:
	var setup: Array = await _load_level()
	var player: PlayerCharacter = setup[1]
	var shader := preload("res://src/feel/occluded_silhouette.gdshader")
	var body := RigidBody3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = SphereMesh.new()
	body.add_child(mesh)
	player.get_parent().add_child(body)
	player.carrier.carry(body)
	var silhouette := mesh.material_overlay.next_pass as ShaderMaterial if mesh.material_overlay else null
	assert_true(silhouette != null and silhouette.shader == shader, "la vasija cargada se ve tras las paredes")
	player.carrier.drop()
	assert_eq(mesh.material_overlay, null, "soltada vuelve a ser normal")
	body.queue_free()


func test_sword_trail_only_while_the_blade_cuts() -> void:
	var setup: Array = await _load_level()
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[1]
	assert_true(player.sword_trail.width > 0.5, "cubre la hoja de la espada")
	assert_true(not player.sword_trail.emitting, "quieto no deja estela")
	_press(&"attack")
	var trailed := 0
	var stray := 0
	for i in 90:
		await tree.process_frame
		if player.sword_trail.emitting:
			trailed += 1
			if not player.attack_runner.is_active():
				stray += 1
	assert_true(trailed > 0, "el tajo deja estela")
	assert_true(stray <= 1, "solo mientras la hitbox está activa (a lo sumo un cuadro de desfase con la física)")
	assert_true(not player.sword_trail.emitting, "y se apaga al terminar")
