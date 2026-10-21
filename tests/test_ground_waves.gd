extends "res://tests/test_case.gd"
## Las ondas del Centinela (11.192): una en cada pisada y una grande en el golpe de la maza; le pegan a todo lo que esté
## en el piso menos al que las larga.

const MODEL := "res://src/entities/centinela/centinela_model.tscn"

var tree: SceneTree
var player: PlayerCharacter


func _start() -> void:
	tree = Engine.get_main_loop() as SceneTree
	tree.root.get_node(^"GameState").reset()
	tree.change_scene_to_file("res://levels/test/test.tscn")
	await tree.scene_changed
	await tree.create_timer(0.3).timeout
	player = tree.get_first_node_in_group(&"player") as PlayerCharacter
	player.health.invulnerability_time = 0.0
	for enemy in tree.get_nodes_in_group(&"enemies"):
		enemy.free()


func _target(at: Vector3, hits: Array) -> Node3D:
	var host := Node3D.new()
	tree.current_scene.add_child(host)
	host.global_position = at
	var hurtbox := Hurtbox.new()
	hurtbox.collision_layer = GroundWaves.HURTBOX_LAYER
	hurtbox.collision_mask = 0
	hurtbox.monitoring = false
	var shape := CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	shape.position.y = 1.0
	hurtbox.add_child(shape)
	host.add_child(hurtbox)
	hurtbox.hit.connect(func(info: DamageInfo) -> void: hits.append(info))
	return host


func _waves(host: Node3D) -> GroundWaves:
	var model := (load(MODEL) as PackedScene).instantiate()
	host.add_child(model)
	return model.get_node(^"Ondas") as GroundWaves


func _until(condition: Callable, timeout := 3.0) -> bool:
	var until := Time.get_ticks_msec() + int(timeout * 1000)
	while Time.get_ticks_msec() < until:
		if condition.call():
			return true
		await tree.physics_frame
	return condition.call()


func test_the_slam_wave_hits_everyone_on_the_floor_but_its_emitter() -> void:
	await _start()
	var own: Array = []
	var other: Array = []
	var center := player.global_position + Vector3(4, 0, 0)
	var sentinel := _target(center, own)
	var skeleton := _target(center + Vector3(0, 0, 4), other)
	var waves := _waves(sentinel)
	await tree.physics_frame
	assert_true(waves.emitter == sentinel, "el que la larga es el padre del modelo")
	var before := player.health.current
	waves.emit(center, true)
	assert_true(await _until(func() -> bool: return waves._rings.is_empty(), 3.0), "la onda se termina")
	assert_true(player.health.current < before, "le pega al player")
	assert_eq(other.size(), 1, "y a otro enemigo, una sola vez")
	assert_eq(own.size(), 0, "no al que la larga")
	skeleton.queue_free()
	sentinel.queue_free()


func test_every_step_and_the_slam_send_a_wave() -> void:
	await _start()
	var sentinel := _target(player.global_position + Vector3(8, 0, 0), [])
	var waves := _waves(sentinel)
	var animation := sentinel.get_node(^"ModelController/AnimationPlayer") as AnimationPlayer
	await tree.process_frame
	animation.play(&"MovementBasic/Walking_A")
	var steps := 0
	var until := Time.get_ticks_msec() + 2500
	var last := 0
	while Time.get_ticks_msec() < until:
		await tree.physics_frame
		if not animation.is_playing():
			animation.play(&"MovementBasic/Walking_A")
		if waves._rings.size() > last:
			steps += 1
		last = waves._rings.size()
	assert_true(steps >= 2, "una onda por pisada (%d)" % steps)
	assert_true(waves._rings.all(func(ring: Dictionary) -> bool: return not ring.slam), "las de las pisadas son chicas")
	await _until(func() -> bool: return waves._rings.is_empty())
	animation.play(&"CombatMelee/Melee_2H_Attack_Chop")
	assert_true(await _until(func() -> bool: return waves._rings.any(func(ring: Dictionary) -> bool: return ring.slam), 2.0), "el golpe de la maza larga la grande")
	sentinel.queue_free()
