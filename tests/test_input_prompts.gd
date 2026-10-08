extends "res://tests/test_case.gd"

const ACTIONS := [&"move_forward", &"attack", &"interact", &"dodge", &"item_1", &"item_2", &"block", &"z-lock",
	&"pause", &"map", &"ui_tab_left", &"ui_tab_right", &"ui_accept", &"ui_cancel"]


func test_every_action_has_both_icons() -> void:
	for action in ACTIONS:
		assert_true(InputPrompts.icon(action, true) != null, "%s sin ícono de gamepad" % action)
		assert_true(InputPrompts.icon(action, false) != null, "%s sin ícono de teclado/mouse" % action)
	for action in [&"look_right", &"target_next"]:
		assert_true(InputPrompts.icon(action, action == &"look_right") != null, str(action))
