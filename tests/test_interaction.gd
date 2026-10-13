extends "res://tests/test_case.gd"

const LEVEL := "res://levels/test.tscn"


func _interactable(text: String, priority: int, at: Vector3, parent: Node) -> Interactable:
	var area := Interactable.new()
	area.prompt = text
	area.prompt_priority = priority
	var shape := CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	area.add_child(shape)
	parent.add_child(area)
	area.global_position = at
	return area


func _face(player: PlayerCharacter, direction: Vector3) -> void:
	player.model.look_at(player.model.global_position - direction, Vector3.UP)


func _settle(tree: SceneTree) -> void:
	for i in 4:
		await tree.physics_frame


func test_prompt_follows_facing_and_hides() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	state.reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	await _settle(tree)
	var scene := tree.current_scene
	scene.get_node(^"Chest").queue_free()
	for enemy in tree.get_nodes_in_group(&"enemies"):
		enemy.queue_free()
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	player.global_position = Vector3(20, 0, 20)
	var hud: Node = scene.get_node(^"HUD")
	_interactable("PROMPT_OPEN", 1, Vector3(21, 0, 20), scene)
	_interactable("PROMPT_READ", 0, Vector3(19, 0, 20), scene)

	_face(player, Vector3.RIGHT)
	await _settle(tree)
	assert_true(hud.prompt.visible, "hay prompt")
	assert_eq(hud.prompt_text.text, "PROMPT_OPEN", "mirando al cofre")
	_face(player, Vector3.LEFT)
	await _settle(tree)
	assert_eq(hud.prompt_text.text, "PROMPT_READ", "mirando a la tablilla")
	_face(player, Vector3.FORWARD)
	await _settle(tree)
	assert_eq(hud.prompt_text.text, "PROMPT_OPEN", "de costado a los dos: gana la prioridad")

	var stack: Node = tree.root.get_node(^"MenuStack")
	stack.push(UiScreen.new())
	assert_eq(hud.prompt.visible, false, "oculto con un menú abierto")
	stack.pop()
	assert_eq(hud.prompt.visible, true)
	player.movement_state.dispatch("dodge")
	await _settle(tree)
	assert_eq(hud.prompt.visible, false, "oculto mientras rueda")
	state.reset()
