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
