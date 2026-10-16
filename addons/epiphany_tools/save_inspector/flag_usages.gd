@tool
extends RefCounted
## Dónde aparece cada flag registrada: nodos de los niveles y líneas de scripts, datos y diálogos.
## Una flag armada en código ("%s_chest" % sala) no se encuentra.

const ROOTS: Array[String] = ["res://levels", "res://src", "res://data", "res://tests"]
const EXTENSIONS: Array[String] = ["tscn", "gd", "tres", "dialogue"]
const SKIP := FlagRegistry.PATH
## Los .tres de mallas y texturas pesan megas y no tienen flags.
const MAX_BYTES := 400_000

## id → [{path, line, node}]; node es la ruta dentro de la escena ("" fuera de un nodo).
var by_id := {}
var built := false

var _quoted := RegEx.create_from_string("\"([a-z][a-z0-9_]*)\"")
var _header := RegEx.create_from_string("name=\"([^\"]*)\"(?:.*?parent=\"([^\"]*)\")?")


func build(ids: Array) -> void:
	by_id.clear()
	var wanted := {}
	for id in ids:
		wanted[String(id)] = true
	for root in ROOTS:
		_scan_dir(root, wanted)
	built = true


func of(id: StringName) -> Array:
	return by_id.get(String(id), [])


func _scan_dir(dir: String, wanted: Dictionary) -> void:
	for sub in DirAccess.get_directories_at(dir):
		_scan_dir(dir.path_join(sub), wanted)
	for file in DirAccess.get_files_at(dir):
		if file.get_extension() in EXTENSIONS:
			_scan_file(dir.path_join(file), wanted)


func _scan_file(path: String, wanted: Dictionary) -> void:
	if path == SKIP:
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES:
		return
	var scene := path.get_extension() == "tscn"
	var node := ""
	var number := 0
	while not file.eof_reached():
		var line := file.get_line()
		number += 1
		if scene and line.begins_with("["):
			node = _node_path(line) if line.begins_with("[node ") else ""
			continue
		if not "\"" in line:
			continue
		for found in _quoted.search_all(line):
			var id := found.get_string(1)
			if wanted.has(id):
				var uses: Array = by_id.get_or_add(id, [])
				uses.append({path = path, line = number, node = node})


func _node_path(header: String) -> String:
	var found := _header.search(header)
	if found == null:
		return ""
	var node_name := found.get_string(1)
	var parent := found.get_string(2)
	if parent.is_empty() and not "parent=" in header:
		return "."
	return node_name if parent == "." else parent.path_join(node_name)
