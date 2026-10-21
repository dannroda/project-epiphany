extends "res://tests/test_case.gd"

const LEVEL := "res://levels/test/test.tscn"
const GUARD := preload("res://src/entities/guard.tscn")


func _frames(tree: SceneTree, count: int) -> void:
	for i in count:
		await tree.physics_frame


func _wait(tree: SceneTree, frames: int, done: Callable) -> bool:
	for i in frames:
		if done.call():
			return true
		await tree.physics_frame
	return done.call()


## Al verte se frena con un !, después persigue; si te pierde corre a donde te vio, mira a los lados y vuelve a su puesto.
func test_guard_alerts_chases_searches_and_returns() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.get_node(^"GameState").reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	var other := tree.get_first_node_in_group(&"enemies") as Enemy
	var guard := GUARD.instantiate() as Enemy
	other.add_sibling(guard)
	guard.global_position = other.global_position
	other.free()
	var home := guard.global_position
	var mark := guard.get_node(^"%Alert") as Label3D
	var blackboard := guard.bt_player.blackboard
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.global_position = home + Vector3(0, 60, 0)
	await _frames(tree, 30)
	assert_true(not mark.visible and not blackboard.get_var(&"alerted", false), "sin verte, tranquilo")
	player.global_position = home + Vector3(0, 0, 7)
	assert_true(await _wait(tree, 30, func() -> bool: return mark.visible), "al verte muestra el !")
	assert_true(guard.desired_velocity.is_zero_approx(), "y se frena")
	assert_true(await _wait(tree, 90, func() -> bool: return blackboard.get_var(&"alerted", false)), "termina la alerta")
	assert_true(not mark.visible, "el ! se va")
	assert_true(await _wait(tree, 30, func() -> bool: return guard.desired_velocity.length() > 0.5), "persigue")
	var seen := player.global_position
	player.global_position = home + Vector3(0, 60, 0)
	assert_true(await _wait(tree, 300, func() -> bool: return Vector2(guard.global_position.x - seen.x, guard.global_position.z - seen.z).length() < 0.6), "va a donde te vio")
	assert_true(await _wait(tree, 30, func() -> bool: return guard.desired_velocity.is_zero_approx()), "se queda mirando")
	assert_true(await _wait(tree, 600, func() -> bool: return Vector2(guard.global_position.x - home.x, guard.global_position.z - home.z).length() < 0.6), "vuelve a su puesto")
	assert_true(await _wait(tree, 60, func() -> bool: return not blackboard.get_var(&"alerted", true)), "y deja la alerta")
	player.global_position = home + Vector3(0, 0, 7)
	assert_true(await _wait(tree, 30, func() -> bool: return mark.visible), "si te vuelve a ver, otra vez el !")
	tree.root.get_node(^"GameState").reset()
