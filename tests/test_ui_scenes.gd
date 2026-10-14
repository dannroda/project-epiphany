extends "res://tests/test_case.gd"
## La UI se arma en escenas: ningún script de src/ui crea Controls ni StyleBoxes por código.


func test_ui_scripts_do_not_build_controls() -> void:
	var bases := {}
	for entry in ProjectSettings.get_global_class_list():
		bases[entry["class"]] = entry["base"]
	var call := RegEx.create_from_string("\\b([A-Z]\\w*)\\.new\\(")
	var offenders: PackedStringArray = []
	for path in _scripts("res://src/ui"):
		var source := FileAccess.get_file_as_string(path)
		for found in call.search_all(source):
			var type := found.get_string(1)
			if _is_ui_type(type, bases):
				offenders.append("%s: %s.new()" % [path.get_file(), type])
	assert_eq(offenders, PackedStringArray(), "usar una escena .tscn")


func test_every_eye_is_the_logo_eye() -> void:
	var eye := load("res://assets/ui/logo/epiphany_eye.png")
	for pair in [["res://src/ui/menus/game_over.tscn", ^"Eye"], ["res://src/ui/title/language_select.tscn", ^"Eye"], ["res://src/flow/scene_flow.tscn", ^"Loading/Busy/Eye"]]:
		var root := (load(pair[0]) as PackedScene).instantiate()
		var node := root.get_node(pair[1]) as TextureRect
		assert_true(node != null and node.texture == eye, "%s usa el ojo del logo" % pair[0].get_file())
		root.free()


func _is_ui_type(type: StringName, bases: Dictionary) -> bool:
	while bases.has(type):
		type = bases[type]
	if not ClassDB.class_exists(type):
		return false
	return ClassDB.is_parent_class(type, &"Control") or ClassDB.is_parent_class(type, &"StyleBox")


func _scripts(dir: String) -> PackedStringArray:
	var found: PackedStringArray = []
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"):
			found.append(dir.path_join(file))
	for sub in DirAccess.get_directories_at(dir):
		found.append_array(_scripts(dir.path_join(sub)))
	return found
