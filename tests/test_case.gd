extends RefCounted

var failures: PackedStringArray = []
var current_test := ""
## Cuántas verificaciones hizo el test actual: si termina en 0, se cortó por un error.
var assertions := 0


func assert_eq(actual: Variant, expected: Variant, message := "") -> void:
	assertions += 1
	if actual != expected:
		_fail("esperaba %s, llegó %s %s" % [var_to_str(expected), var_to_str(actual), message])


func assert_true(condition: bool, message := "") -> void:
	assertions += 1
	if not condition:
		_fail("condición falsa %s" % message)


func _fail(text: String) -> void:
	failures.append("%s: %s" % [current_test, text])


## Último dispositivo = gamepad, con el stick derecho quieto: la mira y el giro con el haz siguen al frente del player
## (con teclado y mouse seguirían al mouse, que en headless queda en una esquina).
func use_gamepad() -> void:
	for value in [0.3, 0.0]:
		var motion := InputEventJoypadMotion.new()
		motion.axis = JOY_AXIS_RIGHT_X
		motion.axis_value = value
		Input.parse_input_event(motion)
