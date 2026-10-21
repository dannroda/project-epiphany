extends "res://tests/test_case.gd"

const LEVEL := "res://levels/test/test.tscn"
const ORB := preload("res://src/entities/projectile.tscn")


func _setup(shield: StringName) -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	state.reset()
	if shield != &"shield_wood":
		state.give(Items.get_item(shield))
		state.equip(Items.get_item(shield))
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	for i in 3:
		await tree.physics_frame
	var enemies := tree.get_nodes_in_group(&"enemies")
	var shooter: Enemy = null
	for enemy in enemies:
		if enemy is Enemy and shooter == null:
			shooter = enemy
		else:
			enemy.free()
	shooter.bt_player.active = false
	shooter.stop_moving()
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	player.global_position = Vector3(0, 0.25, -6)
	player.model.look_at(player.model.global_position - Vector3.RIGHT, Vector3.UP)
	player.health.invulnerability_time = 0.0
	return [tree, state, player, shooter]


func _shoot_from(tree: SceneTree, shooter: Enemy, from: Vector3, at: Vector3, reflectable: bool) -> Projectile:
	shooter.global_position = Vector3(from.x, 0.25, from.z)
	var info := shooter.config.make_damage(shooter)
	info.reflectable = reflectable
	var orb: Projectile = ORB.instantiate()
	tree.current_scene.add_child(orb)
	var start := from + Vector3.UP * 1.3
	orb.launch(start, (at + Vector3.UP * 1.3 - start).normalized() * 12.0, info)
	return orb


func test_arrows_from_behind_hurt() -> void:
	var setup: Array = await _setup(&"shield_wood")
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[2]
	_shoot_from(tree, setup[3], player.global_position - Vector3.RIGHT * 5.0, player.global_position, false)
	await tree.create_timer(0.8).timeout
	assert_true(player.health.current < player.health.max_health, "ya no hay escudo en la espalda")
	setup[1].reset()


func test_guards_only_while_holding_z() -> void:
	var setup: Array = await _setup(&"shield_wood")
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[2]
	_face_the_clear_side(player)
	assert_eq(InputMap.has_action(&"block"), false, "no hay botón de bloquear")
	assert_eq(player.equipment.shield_in_hand.visible, true, "el escudo va en la mano")
	_shoot_from(tree, setup[3], player.global_position - Vector3.RIGHT * 5.0, player.global_position, false)
	await tree.create_timer(0.8).timeout
	assert_true(player.health.current < player.health.max_health, "sin Z, de frente también lastima")
	player.health.current = player.health.max_health
	Input.action_press(&"z-lock")
	await tree.process_frame
	await tree.physics_frame
	assert_eq(player.is_blocking(), true, "con Z mantenido se cubre, aunque no haya blanco")
	_shoot_from(tree, setup[3], player.global_position - Vector3.RIGHT * 5.0, player.global_position, false)
	await tree.create_timer(0.8).timeout
	assert_eq(player.health.current, player.health.max_health, "y frena lo que viene de frente")
	Input.action_release(&"z-lock")
	await tree.process_frame
	await tree.physics_frame
	assert_eq(player.is_blocking(), false)
	assert_eq(player.equipment.shield_in_hand.visible, true, "al soltar sigue en la mano")
	setup[1].reset()


## Por +X el orbe choca enseguida con el nivel; de frente se tira desde -X.
func _face_the_clear_side(player: PlayerCharacter) -> void:
	player.model.look_at(player.model.global_position + Vector3.RIGHT, Vector3.UP)


func test_wood_shield_does_not_stop_explosions() -> void:
	var setup: Array = await _setup(&"shield_wood")
	var player: PlayerCharacter = setup[2]
	var shooter: Enemy = setup[3]
	shooter.global_position = player.global_position + Vector3.RIGHT * 1.5
	hold_block(player, true)
	var slash := shooter.config.make_damage(shooter)
	player.hurtbox.receive(slash)
	assert_eq(player.health.current, player.health.max_health, "un espadazo de frente se bloquea")
	var blast := shooter.config.make_damage(shooter)
	blast.element = &"explosive"
	player.hurtbox.receive(blast)
	assert_true(player.health.current < player.health.max_health, "una explosión pasa aunque se bloquee")
	setup[1].reset()


func test_a_blocked_sword_makes_the_attacker_recoil() -> void:
	var setup: Array = await _setup(&"shield_wood")
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[2]
	var shooter: Enemy = setup[3]
	shooter.global_position = player.global_position + Vector3.RIGHT * 1.5
	hold_block(player, true)
	player.hurtbox.receive(shooter.config.make_damage(shooter))
	assert_true(shooter.is_recoiling() and not shooter.bt_player.active, "el espadazo bloqueado lo deja quieto")
	assert_eq(shooter.anim_player.current_animation, &"General/Hit_B", "aturdido")
	await tree.create_timer(0.7).timeout
	assert_eq(shooter.anim_player.current_animation, &"General/Hit_B", "la animación de aturdido se ve entera")
	await tree.create_timer(player.shield.block_recoil - 0.7 + 0.15).timeout
	assert_true(not shooter.is_recoiling() and shooter.bt_player.active, "un instante, y vuelve a pelear")
	hold_block(player, false)
	setup[1].reset()


func test_a_blocked_arrow_does_not_make_the_archer_recoil() -> void:
	var setup: Array = await _setup(&"shield_wood")
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[2]
	_face_the_clear_side(player)
	hold_block(player, true)
	var arrow := _shoot_from(tree, setup[3], player.global_position - Vector3.RIGHT * 5.0, player.global_position, false)
	await tree.create_timer(0.8).timeout
	assert_eq(is_instance_valid(arrow), false, "llegó hasta el player")
	assert_eq(player.health.current, player.health.max_health, "la flecha se bloquea")
	assert_true(not (setup[3] as Enemy).is_recoiling(), "y el que la tiró sigue en su lugar")
	hold_block(player, false)
	setup[1].reset()


func test_releasing_block_while_frozen_lowers_the_shield() -> void:
	var setup: Array = await _setup(&"shield_wood")
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[2]
	hold_block(player, true)
	await tree.physics_frame
	assert_eq(player.is_blocking(), true, "con el botón mantenido bloquea")
	var mode := player.process_mode
	player.process_mode = Node.PROCESS_MODE_DISABLED
	Input.action_release(player.controls.action(&"z-lock"))
	await tree.physics_frame
	player.process_mode = mode
	await tree.physics_frame
	await tree.physics_frame
	assert_eq(player.is_blocking(), false, "soltar durante un hit-stop baja el escudo")


func test_the_shield_is_a_component_and_controls_are_not_a_node() -> void:
	var setup: Array = await _setup(&"shield_wood")
	var player: PlayerCharacter = setup[2]
	assert_true(player.get_node(^"Shield") == player.shield, "el escudo es un nodo de player.tscn")
	assert_eq(player.shield.item().id, &"shield_wood", "con el escudo equipado")
	assert_true(player.controls is RefCounted and player.find_children("*", "", false, false).all(func(child: Node) -> bool: return child.name != &"Controls"), "los controles no son un nodo hijo")
	setup[1].reset()


## 16.33: la guardia sube con su fundido y solo mueve el brazo del escudo; las piernas siguen lo que venían haciendo.
func test_the_guard_fades_in_on_the_shield_arm_only() -> void:
	var setup: Array = await _setup(&"shield_wood")
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[2]
	var skeleton: Skeleton3D = player.model.get_node(^"Skeleton3D")
	var leg := skeleton.find_bone("upperleg.l")
	var arm := skeleton.find_bone("upperarm.l")
	await tree.create_timer(0.5).timeout
	var leg_before := skeleton.get_bone_pose_rotation(leg)
	var arm_before := skeleton.get_bone_pose_rotation(arm)
	Input.action_press(&"z-lock")
	await tree.create_timer(0.05).timeout
	assert_true(player.anim_tree.get(&"parameters/Guard/active"), "la guardia está subiendo")
	await tree.create_timer(0.5).timeout
	assert_true(skeleton.get_bone_pose_rotation(arm).angle_to(arm_before) > 0.2, "el brazo del escudo sube")
	assert_true(skeleton.get_bone_pose_rotation(leg).angle_to(leg_before) < 0.1, "las piernas no toman la pose de bloquear")
	Input.action_release(&"z-lock")
	await tree.create_timer(0.4).timeout
	assert_true(not player.anim_tree.get(&"parameters/Guard/active"), "al soltar, la guardia baja")
	setup[1].reset()


## Entrar a un estado sin can_guard baja la guardia en el mismo cambio, sin esperar al próximo cuadro (16.37).
func test_dodging_lowers_the_guard_at_once() -> void:
	var setup: Array = await _setup(&"shield_wood")
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[2]
	Input.action_press(&"z-lock")
	await tree.process_frame
	await tree.physics_frame
	assert_eq(player.is_blocking(), true, "cubriéndose")
	assert_true(player.movement_state.dispatch("dodge"), "esquiva")
	assert_eq(player.is_blocking(), false, "al esquivar baja la guardia enseguida")
	Input.action_release(&"z-lock")
	setup[1].reset()


## El escudo va atado al antebrazo, delante del cuerpo y mirando al frente, sin arrastrarlo; al cubrirse sube.
func _shield_center_and_face(player: PlayerCharacter) -> Array:
	var shield := player.equipment.shield_in_hand
	var model := player.model.global_basis.inverse()
	return [model * (shield.global_position - player.global_position), (model * shield.global_basis.z).normalized(), shield.global_basis.z.normalized()]


func test_the_shield_rides_in_front_and_rises_to_block() -> void:
	var setup: Array = await _setup(&"shield_wood")
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[2]
	await tree.create_timer(0.5).timeout
	var rest := _shield_center_and_face(player)
	var radius := ((player.equipment.shield_in_hand.get_node(^"StaticBody3D/CollisionShape3D") as CollisionShape3D).shape as CylinderShape3D).radius
	var face: Vector3 = rest[2]
	var bottom: float = rest[0].y - radius * sqrt(1.0 - face.y * face.y)
	assert_true(rest[1].z > 0.7, "mira al frente %s" % rest[1])
	assert_true(rest[0].z > 0.15, "va delante del cuerpo %s" % rest[0])
	assert_true(bottom > 0.25, "el borde de abajo lejos del piso (%.2f m)" % bottom)
	hold_block(player, true)
	await tree.create_timer(0.5).timeout
	var guard := _shield_center_and_face(player)
	assert_true(guard[1].z > 0.8, "cubriéndose también mira al frente %s" % guard[1])
	assert_true(guard[0].y - rest[0].y > 0.18, "y sube hasta el pecho (%.2f → %.2f)" % [rest[0].y, guard[0].y])
	hold_block(player, false)
	setup[1].reset()


func test_the_shield_arm_lets_go_without_the_shield_in_hand() -> void:
	var setup: Array = await _setup(&"shield_wood")
	var player: PlayerCharacter = setup[2]
	assert_eq(player.anim_tree.get(&"parameters/ShieldArm/blend_amount"), 1.0, "con el escudo, el brazo lo sostiene")
	player.equipment.hold(Items.get_item(&"bow"))
	assert_eq(player.anim_tree.get(&"parameters/ShieldArm/blend_amount"), 0.0, "con el arco en esa mano, lo suelta")
	assert_eq(player.anim_tree.get(&"parameters/ShieldRoll/blend_amount"), 0.0, "también al rodar")
	player.equipment.release_held()
	assert_eq(player.anim_tree.get(&"parameters/ShieldArm/blend_amount"), 1.0, "y vuelve")
	setup[1].reset()
