extends "res://tests/test_case.gd"
## Agua baja (el Bañado): frena a los players adentro; sus áreas se tocan, así que pasar de una a la otra sigue frenando.

const WATER := preload("res://src/world/water/shallow_water.tscn")


func test_crossing_into_the_next_water_keeps_wading() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	tree.change_scene_to_file("res://levels/test.tscn")
	await tree.scene_changed
	await tree.physics_frame
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	var first := WATER.instantiate() as ShallowWater
	var second := WATER.instantiate() as ShallowWater
	second.wade_speed = 0.5
	tree.current_scene.add_child(first)
	tree.current_scene.add_child(second)
	first.global_position = Vector3(100, 0, 100)
	second.global_position = Vector3(108, 0, 100)
	first.body_entered.emit(player)
	second.body_entered.emit(player)
	first.body_exited.emit(player)
	assert_eq(player.ground_speed, 0.5, "sigue frenado por la segunda")
	second.body_exited.emit(player)
	assert_eq(player.ground_speed, 1.0, "fuera del agua, la de siempre")
	tree.root.get_node(^"GameState").reset()
