extends "res://tests/test_case.gd"
## Un grupo que se busca con un nombre escrito a mano tiene que existir: un typo no da error, solo no encuentra nada.

const ROOTS: Array[String] = ["res://src", "res://player", "res://levels"]

var _lookup := RegEx.create_from_string("(?:get_nodes_in_group|get_first_node_in_group|call_group|is_in_group|has_group)\\(&?\"([a-z_]+)\"")
var _added := RegEx.create_from_string("(?:add_to_group\\(&?\"|GROUP := &\"|[A-Z_]+ := &\")([a-z_]+)\"")
var _in_scene := RegEx.create_from_string("groups=\\[([^\\]]*)\\]")


func test_every_group_looked_up_by_name_is_added_somewhere() -> void:
	var looked := {}
	var added := {}
	for root in ROOTS:
		_scan(root, looked, added)
	assert_true(not looked.is_empty() or not added.is_empty(), "leyó scripts")
	for group: String in looked:
		assert_true(added.has(group), "%s busca el grupo %s y nadie lo agrega" % [looked[group], group])


func _scan(dir: String, looked: Dictionary, added: Dictionary) -> void:
	for sub in DirAccess.get_directories_at(dir):
		_scan(dir.path_join(sub), looked, added)
	for file in DirAccess.get_files_at(dir):
		var path := dir.path_join(file)
		if file.ends_with(".gd"):
			var text := FileAccess.get_file_as_string(path)
			for found in _lookup.search_all(text):
				looked[found.get_string(1)] = path.get_file()
			for found in _added.search_all(text):
				added[found.get_string(1)] = true
		elif file.ends_with(".tscn") and FileAccess.open(path, FileAccess.READ).get_length() < 2_000_000:
			for found in _in_scene.search_all(FileAccess.get_file_as_string(path)):
				for group in found.get_string(1).split(","):
					added[group.strip_edges().trim_prefix("\"").trim_suffix("\"")] = true
