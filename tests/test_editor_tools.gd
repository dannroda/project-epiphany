extends "res://tests/test_case.gd"
## Los scripts del Save Inspector usan constantes de SaveManager y SaveCodec: si cambian, el plugin deja de cargar en el editor.


func test_save_inspector_scripts_compile() -> void:
	var folder := "res://addons/epiphany_tools/save_inspector/"
	var files := ["save_inspector.gd"]
	for file in DirAccess.get_files_at(folder + "tabs"):
		if file.ends_with(".gd"):
			files.append("tabs/" + file)
	for file in files:
		var script := load(folder + file) as GDScript
		assert_true(script != null and script.can_instantiate(), "%s compila" % file)
