extends "res://tests/test_case.gd"
## El martillo (11.191): un golpe al piso delante del player; lo que pega es golpe fuerte (DamageInfo.strong), lo único
## que rompe lo que tiene needs_strong y lo que baja escudos y corazas.

const LEVEL := "res://levels/test.tscn"

var tree: SceneTree
var state: Node
var player: PlayerCharacter


func _start() -> void:
	tree = Engine.get_main_loop() as SceneTree
	state = tree.root.get_node(^"GameState")
	state.reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	for i in 3:
		await tree.physics_frame
	for enemy in tree.get_nodes_in_group(&"enemies"):
		enemy.queue_free()
	player = tree.get_first_node_in_group(&"player") as PlayerCharacter
	use_gamepad()
	state.give(Items.get_item(&"hammer"))
	state.assign_button(0, &"hammer")


func _face_and_press(target: Vector3, action: StringName) -> void:
	player.global_position = target + Vector3(0, 0, 1.2)
	player.velocity = Vector3.ZERO
	player.model.look_at(player.model.global_position + Vector3.BACK, Vector3.UP)
	for i in 3:
		await tree.physics_frame
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
	await tree.create_timer(1.4).timeout


func test_the_hammer_is_a_button_item_with_its_icon_and_texts() -> void:
	var hammer := Items.get_item(&"hammer")
	assert_true(hammer != null and hammer.behavior is StrikeBehavior, "el martillo es un ítem de botón")
	assert_eq(hammer.category, ItemData.Category.USABLE)
	assert_true(hammer.icon != null and hammer.pickup_mesh != null and hammer.equip_scene != null, "ícono, malla tirado y en la mano")
	for key in ["ITEM_HAMMER_NAME", "ITEM_HAMMER_DESC", "ITEM_HAMMER_GOT"]:
		assert_true(tr(key) != key, "%s está traducido" % key)


func test_only_the_hammer_breaks_what_needs_a_strong_hit() -> void:
	await _start()
	var pot: Breakable = tree.current_scene.get_node(^"Pot1")
	pot.needs_strong = true
	var hits: Array[DamageInfo] = []
	pot.hurtbox.hit.connect(func(info: DamageInfo) -> void: hits.append(info))
	await _face_and_press(pot.global_position, &"attack")
	assert_true(not hits.is_empty() and not hits.back().strong, "la espada le pega sin golpe fuerte")
	assert_true(is_instance_valid(pot) and not pot.broken, "y rebota")
	await _face_and_press(pot.global_position, &"item_1")
	assert_true(not hits.is_empty() and hits.back().strong, "el martillazo es golpe fuerte")
	assert_true(not is_instance_valid(pot), "y la rompe")
	state.reset()


func test_an_attack_marked_strong_hits_strong() -> void:
	var hitbox := Hitbox.new()
	hitbox.damage_factory = func() -> DamageInfo: return DamageInfo.make(1, 0.0, null)
	assert_true(not hitbox.build_damage().strong, "un golpe común no es fuerte")
	var attack := AttackData.new()
	attack.strong = true
	hitbox.active_attack = attack
	assert_true(hitbox.build_damage().strong, "AttackData.strong lo vuelve fuerte")
	hitbox.free()
