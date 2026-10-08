extends "res://tests/test_case.gd"

const LEVEL := "res://levels/test.tscn"


func _setup(arrows: int) -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	state.reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	for i in 3:
		await tree.physics_frame
	for enemy in tree.get_nodes_in_group(&"enemies"):
		enemy.free()
	state.give(Items.get_item(&"bow"))
	if arrows > 0:
		state.give(Items.get_item(&"arrow"), arrows)
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	var eye: EyeSwitch = tree.current_scene.get_node(^"EyeSwitch")
	player.global_position = eye.global_position + Vector3(0, 0, 7)
	for i in 3:
		await tree.physics_frame
	return [tree, state, player, eye]


func _action(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)


func _shoot(tree: SceneTree, player: PlayerCharacter) -> void:
	_action(&"item_1", true)
	await tree.create_timer(0.4).timeout
	assert_eq(player.movement_state.get_active_state().name, &"AimingItem", "mantener apunta")
	assert_true(player.aim.aiming, "el modelo sigue la mira")
	_action(&"item_1", false)
	await tree.create_timer(0.8).timeout


func _face(player: PlayerCharacter, direction: Vector3) -> void:
	player.model.look_at(player.model.global_position - direction, Vector3.UP)


func test_shoot_eye_switch_facing_it() -> void:
	var setup: Array = await _setup(10)
	var tree: SceneTree = setup[0]
	var state: Node = setup[1]
	var player: PlayerCharacter = setup[2]
	var eye: EyeSwitch = setup[3]
	var activations: Array = []
	eye.activated.connect(func() -> void: activations.append(true))
	_face(player, Vector3.FORWARD)
	await _shoot(tree, player)
	assert_eq(state.inventory.count(&"arrow"), 9, "gasta una flecha")
	assert_eq(activations.size(), 1, "la flecha activa el ojo a distancia")
	assert_eq(player.movement_state.get_active_state().name, &"Idle", "vuelve a Idle")
	assert_eq(player.aim.aiming, false)
	state.reset()


func test_shoot_with_right_stick() -> void:
	var setup: Array = await _setup(10)
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[2]
	var eye: EyeSwitch = setup[3]
	_face(player, Vector3.RIGHT)
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_RIGHT_Y
	stick.axis_value = -1.0
	Input.parse_input_event(stick)
	await tree.physics_frame
	await _shoot(tree, player)
	stick.axis_value = 0.0
	Input.parse_input_event(stick)
	assert_eq(eye.active, true, "el stick derecho apunta aunque el player mire a otro lado")
	setup[1].reset()


func test_no_arrows_denies() -> void:
	var setup: Array = await _setup(0)
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[2]
	var denied: Array = []
	player.item_denied.connect(func(button: int) -> void: denied.append(button))
	_action(&"item_1", true)
	for i in 3:
		await tree.physics_frame
	_action(&"item_1", false)
	assert_eq(denied, [0], "sin flechas suena el no se puede")
	assert_true(player.movement_state.get_active_state().name != &"AimingItem", "no tensa el arco")
	setup[1].reset()


func test_big_quiver_raises_capacity() -> void:
	var state: Node = (Engine.get_main_loop() as SceneTree).root.get_node(^"GameState")
	state.reset()
	assert_eq(state.inventory.capacity(&"arrow"), 30)
	state.give(Items.get_item(&"quiver_big"))
	assert_eq(state.inventory.capacity(&"arrow"), 50, "el carcaj grande suma 20")
	state.reset()


func test_left_stick_aims_while_drawing() -> void:
	var setup: Array = await _setup(10)
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[2]
	var eye: EyeSwitch = setup[3]
	_face(player, Vector3.RIGHT)
	var start := player.global_position
	_action(&"item_1", true)
	await tree.create_timer(0.2).timeout
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_Y
	stick.axis_value = -1.0
	Input.parse_input_event(stick)
	await tree.create_timer(0.4).timeout
	assert_true(player.global_position.distance_to(start) < 0.05, "tensando, el stick izquierdo no camina")
	assert_eq(player.aim.source, Aim.Source.MOVE_STICK, "apunta con el stick izquierdo")
	_action(&"item_1", false)
	await tree.create_timer(0.8).timeout
	stick.axis_value = 0.0
	Input.parse_input_event(stick)
	assert_eq(eye.active, true, "la flecha va hacia donde apunta el stick izquierdo")
	setup[1].reset()


func _arrows(tree: SceneTree) -> Array:
	return tree.current_scene.get_children().filter(func(n: Node) -> bool: return n is Projectile and not n.is_queued_for_deletion())


func test_arrow_ignores_own_shield_collision() -> void:
	var setup: Array = await _setup(10)
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[2]
	var shield_bodies := player.equipment.shield_hand_socket.find_children("*", "StaticBody3D", true, false)
	assert_true(not shield_bodies.is_empty(), "el escudo de KayKit trae colisión propia")
	var shield := shield_bodies[0] as Node3D
	var arrow: Projectile = preload("res://src/items/arrow/arrow.tscn").instantiate()
	tree.current_scene.add_child(arrow)
	var info := Items.get_item(&"bow").make_damage(player)
	info.team = EntityConfig.Team.PLAYER
	arrow.launch(shield.global_position + Vector3(-0.6, 0, 0), Vector3.RIGHT * 20.0, info)
	for i in 6:
		await tree.physics_frame
	assert_eq(arrow._stuck, false, "atraviesa el escudo (oculto) de la mano en vez de clavarse en el aire")
	assert_true(arrow.global_position.distance_to(shield.global_position) > 1.0, "sigue volando")
	setup[1].reset()


func test_locked_bow_strafes_and_hits_target() -> void:
	var setup: Array = await _setup(10)
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[2]
	var eye: EyeSwitch = setup[3]
	var box := tree.current_scene.get_node(^"Caja3") as Node3D
	box.global_position = player.global_position + Vector3(0, 0.6, -6)
	box.freeze = true
	await tree.physics_frame
	player.targeting.set_target(box)
	var start := player.global_position
	_action(&"item_1", true)
	await tree.create_timer(0.2).timeout
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_X
	stick.axis_value = 1.0
	Input.parse_input_event(stick)
	await tree.create_timer(0.5).timeout
	assert_true(player.global_position.distance_to(start) > 0.5, "fijado, el stick izquierdo camina")
	assert_eq(player.aim.source, Aim.Source.TARGET, "apunta al objetivo")
	assert_eq(player.anim_tree.get(&"parameters/Combat/current_state"), "Targeting", "piernas en strafe")
	stick.axis_value = 0.0
	Input.parse_input_event(stick)
	_action(&"item_1", false)
	await tree.create_timer(0.1).timeout
	var arrows := _arrows(tree)
	assert_eq(arrows.size(), 1)
	if arrows.size() == 1:
		var to_box: Vector3 = box.global_position - arrows[0].global_position
		to_box.y = 0.0
		assert_true(arrows[0].velocity.normalized().dot(to_box.normalized()) > 0.95, "la flecha va hacia el objetivo")
	player.targeting.clear()
	setup[1].reset()


func test_unlocked_bow_legs_rest() -> void:
	var setup: Array = await _setup(10)
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[2]
	player.anim_tree.set(&"parameters/Combat/transition_request", "Targeting")
	player.anim_tree["parameters/Targeting/blend_position"] = Vector2(1, 0)
	_action(&"item_1", true)
	await tree.create_timer(0.3).timeout
	assert_eq(player.anim_tree.get(&"parameters/Combat/current_state"), "Normal", "sin objetivo, piernas normales")
	_action(&"item_1", false)
	await tree.create_timer(0.6).timeout
	setup[1].reset()


## Ángulo entre la línea de la flecha en la animación (mano de la cuerda → mano del arco) y la mira.
func _bow_error(player: PlayerCharacter) -> float:
	var skeleton: Skeleton3D = player.model.get_node(^"Skeleton3D")
	var bow_hand := (skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("hand.l"))).origin
	var string_hand := (skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("hand.r"))).origin
	var line := bow_hand - string_hand
	line.y = 0.0
	return absf(rad_to_deg(player.aim.get_direction().angle_to(line.normalized())))


func test_bow_points_where_it_aims() -> void:
	var setup: Array = await _setup(10)
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[2]
	_face(player, Vector3.RIGHT)
	_action(&"item_1", true)
	await tree.create_timer(2.0).timeout
	assert_true(_bow_error(player) < 5.0, "sin objetivo, el arco apunta a la mira (error %.1f°)" % _bow_error(player))
	var box := tree.current_scene.get_node(^"Caja3") as RigidBody3D
	box.global_position = player.global_position + Vector3(-4, 0.6, 4)
	box.freeze = true
	await tree.physics_frame
	player.targeting.set_target(box)
	await tree.create_timer(0.8).timeout
	assert_true(_bow_error(player) < 5.0, "fijado, el arco apunta al objetivo (error %.1f°)" % _bow_error(player))
	_action(&"item_1", false)
	await tree.create_timer(0.5).timeout
	player.targeting.clear()
	setup[1].reset()


func test_hidden_shield_has_no_collision() -> void:
	var setup: Array = await _setup(0)
	var tree: SceneTree = setup[0]
	var player: PlayerCharacter = setup[2]
	await tree.physics_frame
	var hand_shapes := player.equipment.shield_in_hand.find_children("*", "CollisionShape3D", true, false)
	var back_shapes := player.equipment.shield_on_back.find_children("*", "CollisionShape3D", true, false)
	assert_true(hand_shapes.all(func(s: CollisionShape3D) -> bool: return s.disabled), "escudo de la mano oculto: sin colisión")
	assert_true(back_shapes.all(func(s: CollisionShape3D) -> bool: return not s.disabled), "escudo en la espalda: con colisión")
	player.movement_state.blackboard.set_var("is_blocking", true)
	player.set_guard(true)
	await tree.physics_frame
	await tree.physics_frame
	assert_true(hand_shapes.all(func(s: CollisionShape3D) -> bool: return not s.disabled), "al bloquear, el de la mano colisiona")
	assert_true(back_shapes.all(func(s: CollisionShape3D) -> bool: return s.disabled), "y el de la espalda no")
	player.movement_state.blackboard.set_var("is_blocking", false)
	player.set_guard(false)
	setup[1].reset()
