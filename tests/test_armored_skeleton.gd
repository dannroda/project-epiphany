extends "res://tests/test_case.gd"

const LEVEL := "res://levels/test/test.tscn"
const ARMORED_SKELETON := preload("res://src/entities/armored_skeleton.tscn")


func _setup() -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.get_node(^"GameState").reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	for enemy in tree.get_nodes_in_group(&"enemies"):
		enemy.free()
	var skeleton: Enemy = ARMORED_SKELETON.instantiate()
	skeleton.position = Vector3(0, 0.25, -4)
	tree.current_scene.add_child(skeleton)
	skeleton.bt_player.active = false
	await tree.physics_frame
	skeleton.health.invulnerability_time = 0.0
	var attacker := Node3D.new()
	tree.current_scene.add_child(attacker)
	return [tree, skeleton, attacker]


func _hit(skeleton: Enemy, attacker: Node3D, from: Vector3, element := &"") -> int:
	attacker.global_position = skeleton.global_position + from
	var info := DamageInfo.new()
	info.amount = 2
	info.source = attacker
	info.team = EntityConfig.Team.PLAYER
	info.element = element
	var before := skeleton.health.current
	skeleton.hurtbox.receive(info)
	return before - skeleton.health.current


func test_only_a_bomb_breaks_the_armor() -> void:
	var setup: Array = await _setup()
	var tree: SceneTree = setup[0]
	var skeleton: Enemy = setup[1]
	var attacker: Node3D = setup[2]
	assert_true(skeleton.is_armored(), "empieza con coraza")
	assert_eq(_hit(skeleton, attacker, Vector3(0, 0, 2)), 0, "la espada rebota de frente")
	assert_eq(skeleton.hurtbox.surface, "metal", "y suena a metal")
	assert_eq(_hit(skeleton, attacker, Vector3(0, 0, -2)), 0, "y por la espalda")
	assert_eq(_hit(skeleton, attacker, Vector3(0, 0, 2), &"explosive"), 2, "la bomba lo daña")
	assert_true(not skeleton.is_armored(), "y le vuela la coraza")
	assert_true(skeleton.bt_player.blackboard.get_var("stunned", false), "queda aturdido")
	assert_true(skeleton.model.find_child("Armor", true, false) == null, "la coraza ya no está en el cuerpo")
	assert_eq(_hit(skeleton, attacker, Vector3(0, 0, 2)), 2, "después la espada entra")
	assert_eq(skeleton.hurtbox.surface, "flesh", "y suena a carne")
	await tree.create_timer(3.0).timeout
	assert_true(tree.current_scene.find_children("Armor", "", true, false).is_empty(), "la pieza suelta desaparece")
	tree.root.get_node(^"GameState").reset()
