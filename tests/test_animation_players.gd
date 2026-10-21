extends "res://tests/test_case.gd"
## 16.40: los AnimationPlayer no son deterministas, así al cambiar de clip lo que el clip nuevo no anima queda como
## estaba en vez de volver al valor inicial. Los que alimentan un AnimationTree (anim_player) los mezcla el árbol.
## Desde 4.8 false es el valor por defecto y el editor no lo escribe.

const FOLDERS := ["res://src", "res://levels", "res://player"]


func test_animation_players_are_not_deterministic() -> void:
	var checked := 0
	for path in _scenes():
		var text := FileAccess.get_file_as_string(path)
		if text.contains("anim_player = "):
			continue
		for block in text.split("\n["):
			if block.begins_with("node ") and block.contains('type="AnimationPlayer"'):
				checked += 1
				assert_true(not block.contains("deterministic = true"), "%s: %s" % [path, block.get_slice("\n", 0)])
	assert_true(checked > 20, "revisó los AnimationPlayer (%d)" % checked)


func _scenes() -> PackedStringArray:
	var found := PackedStringArray()
	var pending := FOLDERS.duplicate()
	while not pending.is_empty():
		var dir: String = pending.pop_back()
		for sub in DirAccess.get_directories_at(dir):
			pending.append(dir.path_join(sub))
		for file in DirAccess.get_files_at(dir):
			if file.ends_with(".tscn"):
				found.append(dir.path_join(file))
	return found
