extends "res://tests/test_case.gd"
## Co-op (13.6): el P2 se viste con sus colores, con o sin armadura.

const PAD_1 := 0
const PAD_2 := 1
const P2_BODY := preload("res://data/materials/player_p2.tres")
const ARMOR := preload("res://data/materials/armor_reforzada.tres")
const ARMOR_P2 := preload("res://data/materials/armor_reforzada_p2.tres")


func _body(player: PlayerCharacter) -> Material:
	return (player.get_node(^"ModelController/Visuals/Body") as MeshInstance3D).material_override


func test_the_second_player_wears_their_own_colors() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var players: Node = tree.root.get_node(^"Players")
	GameState.reset()
	tree.change_scene_to_file("res://levels/test/test_rooms.tscn")
	await tree.scene_changed
	for i in 3:
		await tree.physics_frame
	players.lead_pad = PAD_1
	var second: PlayerCharacter = players.join(PAD_2)
	await tree.physics_frame
	var first: PlayerCharacter = players.lead()
	assert_eq(_body(first), null, "el P1 con los colores del modelo")
	assert_eq(_body(second), P2_BODY, "el P2 con los suyos")

	GameState.give(Items.get_item(&"armor_chainmail"))
	GameState.equip(Items.get_item(&"armor_chainmail"))
	await tree.process_frame
	assert_eq(_body(first), ARMOR, "con la cota: la del P1")
	assert_eq(_body(second), ARMOR_P2, "y la del P2")
	for slot in players.guests.keys():
		players.leave(slot)
	players.lead_pad = -1
	await tree.process_frame
	GameState.reset()
