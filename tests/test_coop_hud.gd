extends "res://tests/test_case.gd"
## Co-op (13.5): el HUD tiene un panel por player con sus corazones; al salir el P2 vuelve el de un jugador.

const PAD_1 := 0
const PAD_2 := 1


func _hearts(panel: PlayerPanel) -> Array:
	return panel.hearts.get_children().map(func(heart: HeartIcon) -> int: return heart.quarters)


func test_each_player_gets_a_panel_and_it_goes_when_they_leave() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	var players: Node = tree.root.get_node(^"Players")
	state.reset()
	tree.change_scene_to_file("res://levels/temple.tscn")
	await tree.scene_changed
	for i in 5:
		await tree.process_frame
	var hud: CanvasLayer = tree.get_first_node_in_group(&"hud")
	assert_eq(hud.panels.get_child_count(), 1, "solo: un panel")
	assert_true((hud.panels.get_child(0) as PlayerPanel).tag == null, "el de siempre, sin etiqueta")

	players.lead_pad = PAD_1
	var second: PlayerCharacter = players.join(PAD_2)
	for i in 3:
		await tree.process_frame
	var first_panel: PlayerPanel = hud.panel_of(players.lead())
	var second_panel: PlayerPanel = hud.panel_of(second)
	assert_eq(hud.panels.get_child_count(), 2, "co-op: uno por player")
	assert_true(first_panel != null and second_panel != null and first_panel != second_panel, "cada uno el suyo")
	assert_eq((second_panel.tag.get_node(^"Label") as Label).text, "P2")
	assert_true(second_panel.is_layout_rtl() and not first_panel.is_layout_rtl(), "el del P2 en espejo, a la derecha")
	assert_true(second_panel.get_global_rect().position.x > first_panel.get_global_rect().end.x, "en la otra esquina")
	assert_true(hud.coop_keys.visible and hud.keys.get_parent().get_parent() == hud.coop_keys, "en mazmorra, las llaves al medio")

	var before: Array = _hearts(first_panel)
	second.health.damage(4)
	await tree.process_frame
	assert_eq(_hearts(first_panel), before, "al P1 no le cambia nada")
	assert_true(_hearts(second_panel) != before, "el P2 ve sus corazones")

	players.leave(1)
	for i in 3:
		await tree.process_frame
	assert_eq(hud.panels.get_child_count(), 1, "al salir el P2 su panel se va")
	var solo: PlayerPanel = hud.panels.get_child(0)
	assert_true(solo.tag == null and hud.keys.get_parent() == solo.keys_spot, "vuelve el de un jugador, con las llaves abajo")
	players.lead_pad = -1
	state.reset()
