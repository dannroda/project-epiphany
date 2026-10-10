extends "res://tests/test_case.gd"

const LEVEL := "res://levels/overworld.tscn"


func _open(text: String) -> TextBox:
	return TextBox.open(DialogueManager.create_resource_from_text("~ start\n" + text + "\n=> END"), "start")


func test_button_tokens_show_icons() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	state.reset()
	state.item_buttons[1] = &"bomb_bag"
	var box := _open("Levantá con {btn:interact}, andá con {btn:move} y tirá con {item:bomb_bag}.")
	await tree.process_frame
	await tree.process_frame
	assert_true(box.body is RichTextLabel, "con íconos usa el texto enriquecido")
	var text: String = box.body.get_parsed_text()
	assert_eq(text.contains("{"), false, "no quedan tokens: " + text)
	assert_true(text.begins_with("Levantá con "), text)
	box.advance()
	box.advance()
	await tree.process_frame
	state.reset()


func test_plain_lines_keep_the_label() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var box := _open("Sin botones.")
	await tree.process_frame
	await tree.process_frame
	assert_true(box.body is Label, "sin tokens queda el Label")
	box.advance()
	box.advance()
	await tree.process_frame


func test_tablets_in_the_clearing_have_their_cues() -> void:
	var resource := DialogueManager.create_resource_from_text(FileAccess.get_file_as_string("res://data/dialogue/overworld.dialogue"))
	for cue in ["start_controls", "start_combat", "start_lift"]:
		var line: DialogueLine = await DialogueManager.get_next_dialogue_line(resource, cue)
		assert_true(line != null and line.text.contains("{btn:"), "%s trae botones" % cue)


func test_throwing_the_stone_on_the_plate_opens_the_niche() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var state: Node = tree.root.get_node(^"GameState")
	state.reset()
	tree.change_scene_to_file(LEVEL)
	await tree.scene_changed
	for i in 3:
		await tree.physics_frame
	var level := tree.current_scene
	var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
	var stone: Node3D = level.get_node(^"LiftStone")
	var plate: FloorSwitch = level.get_node(^"LiftSwitch")
	var gate: Node3D = level.get_node(^"LiftGate")
	var toward: Vector3 = plate.global_position - stone.global_position
	toward.y = 0.0
	toward = toward.normalized()
	player.global_position = stone.global_position - toward
	player.model.look_at(player.model.global_position - toward, Vector3.UP)
	for i in 3:
		await tree.physics_frame
	var press := InputEventAction.new()
	press.action = &"interact"
	press.pressed = true
	Input.parse_input_event(press)
	await tree.physics_frame
	var release := InputEventAction.new()
	release.action = &"interact"
	Input.parse_input_event(release)
	await tree.create_timer(0.8).timeout
	assert_eq(player.movement_state.get_active_state().name, &"Carrying", "levanta la piedra")
	var distance := (plate.global_position - player.global_position) * Vector3(1, 0, 1)
	player.global_position += toward * (distance.length() - 4.5)
	await tree.physics_frame
	Input.parse_input_event(press)
	await tree.physics_frame
	Input.parse_input_event(release)
	await tree.create_timer(2.0).timeout
	assert_true(plate.active, "la piedra cae en la placa (%s, placa %s, player %s)" % [stone.global_position, plate.global_position, player.global_position])
	assert_eq(state.get_flag(&"ow_start_lift_switch"), true, "queda trabada")
	assert_true(gate.is_open, "la reja del nicho se abre")
	state.reset()
