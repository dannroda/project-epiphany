extends RefCounted

var failures: PackedStringArray = []
var current_test := ""


func assert_eq(actual: Variant, expected: Variant, message := "") -> void:
	if actual != expected:
		_fail("esperaba %s, llegó %s %s" % [var_to_str(expected), var_to_str(actual), message])


func assert_true(condition: bool, message := "") -> void:
	if not condition:
		_fail("condición falsa %s" % message)


func _fail(text: String) -> void:
	failures.append("%s: %s" % [current_test, text])
