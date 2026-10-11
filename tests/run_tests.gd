# godot --headless --path . --script res://tests/run_tests.gd
extends SceneTree

const DIR := "res://tests"


func _initialize() -> void:
	await process_frame
	root.get_node(^"SaveManager").save_dir = "user://test_saves/"
	root.get_node(^"Settings").path = "user://test_settings.cfg"
	root.get_node(^"Settings").set_value(&"language", "es")
	var total := 0
	var failures: PackedStringArray = []
	for file in DirAccess.get_files_at(DIR):
		if not (file.begins_with("test_") and file.ends_with(".gd")) or file == "test_case.gd":
			continue
		var script: GDScript = load(DIR.path_join(file))
		if script == null or not script.can_instantiate():
			total += 1
			failures.append("%s: no compila" % file.get_basename())
			print("FALLA %s (no compila)" % file.get_basename())
			continue
		var suite: RefCounted = script.new()
		for method in suite.get_method_list():
			var test_name: String = method.name
			if not test_name.begins_with("test_"):
				continue
			total += 1
			suite.current_test = "%s › %s" % [file.get_basename(), test_name]
			var before: int = suite.failures.size()
			suite.assertions = 0
			await suite.call(test_name)
			if suite.assertions == 0:
				suite.failures.append("%s: no llegó a verificar nada (¿se cortó por un error?)" % suite.current_test)
			print("%s %s" % ["ok  " if suite.failures.size() == before else "FALLA", suite.current_test])
		failures.append_array(suite.failures)
	for failure in failures:
		printerr(failure)
	print("%d tests, %d fallos" % [total, failures.size()])
	quit(1 if not failures.is_empty() else 0)
