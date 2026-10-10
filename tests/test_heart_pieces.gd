extends "res://tests/test_case.gd"

const PIECE := preload("res://data/items/heart_piece.tres")
const ItemGet := preload("res://src/ui/item_get/item_get.gd")


func _state() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node(^"GameState")


func test_four_pieces_make_a_heart() -> void:
	var state := _state()
	state.reset()
	var start: int = state.max_health
	for i in 3:
		state.give(PIECE)
		assert_eq(ItemGet.cue_for(PIECE), StringName("heart_piece_%d" % (i + 1)))
	assert_eq(state.max_health, start, "tres piezas no alcanzan")
	assert_eq(state.heart_pieces(), 3)
	state.give(PIECE)
	assert_eq(state.max_health, start + 4, "la cuarta suma un corazón")
	assert_eq(state.heart_pieces(), 0)
	assert_eq(ItemGet.cue_for(PIECE), &"heart_piece_full", "la cuarta tiene su propio item get")
	state.reset()


func test_pieces_are_saved() -> void:
	var state := _state()
	state.reset()
	state.give(PIECE)
	state.give(PIECE)
	var cfg := ConfigFile.new()
	state.write_to(cfg)
	state.reset()
	state.read_from(cfg)
	assert_eq(state.heart_pieces(), 2)
	state.reset()


func test_piece_in_the_world_is_taken_once() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state := _state()
	state.reset()
	tree.change_scene_to_file("res://levels/overworld.tscn")
	await tree.scene_changed
	await tree.physics_frame
	var pieces := tree.current_scene.find_children("*", "HeartPiece", false, false)
	assert_true(pieces.size() >= 4, "hay al menos cuatro escondidas (%d)" % pieces.size())
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	var piece: HeartPiece = tree.current_scene.get_node(^"HeartPieceGrotto")
	piece.collect(player)
	assert_eq(state.heart_pieces(), 1)
	assert_eq(state.get_flag(&"ow_heart_piece_grotto"), true)
	var stack: Node = tree.root.get_node(^"MenuStack")
	for i in 120:
		await tree.process_frame
		if stack.top() != null:
			break
	if stack.top() != null:
		stack.pop()
	tree.change_scene_to_file("res://levels/overworld.tscn")
	await tree.scene_changed
	await tree.process_frame
	assert_true(tree.current_scene.get_node(^"HeartPieceGrotto").taken, "no vuelve a aparecer")
	assert_eq(tree.current_scene.get_node(^"HeartPieceGrotto").visible, false)
	assert_true(tree.current_scene.has_node(^"HeartPieceMeadow"), "las otras siguen")
	state.reset()


func test_equipment_page_counts_pieces() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state := _state()
	state.reset()
	state.give(PIECE)
	state.give(PIECE)
	var page: Control = load("res://src/ui/menus/equipment_page.tscn").instantiate()
	tree.root.add_child(page)
	await tree.process_frame
	assert_eq(page.pieces_value.text, "2 / 4")
	var shown: Array = page.pieces_icon.quarters.filter(func(quarter: Control) -> bool: return quarter.visible)
	assert_eq(shown.size(), 2, "dos cuartos llenos")
	page.queue_free()
	state.reset()
