@tool
extends EditorScript

# Root directory to start the recursive conversion (e.g., "res://")
const TARGET_DIR = "res://player/animation/anim_bin"
const OUTPUT_DIR = "res://player/animation/anim"

var bin2text:bool = false

func _run() -> void:
	_scan_and_convert(TARGET_DIR)
	print("Resource conversion complete!")

func _scan_and_convert(path: String) -> void:
	var from_extension:String
	var to_extension:String
	if bin2text:
		from_extension = ".res"
		to_extension = ".tres"
	else:
		from_extension = ".tres"
		to_extension = ".res"
		
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				if not file_name.begins_with("."):
					_scan_and_convert(path.path_join(file_name))
			else:
				if file_name.ends_with(from_extension):
					var res_path = path.path_join(file_name)
					var tres_path = res_path.get_basename() + to_extension
					tres_path = tres_path.replace(TARGET_DIR, OUTPUT_DIR)
					
					var output_dir = tres_path.get_base_dir()
					if not DirAccess.dir_exists_absolute(output_dir):
						DirAccess.make_dir_recursive_absolute(output_dir)
					
					var res = load(res_path)
					if res:
						ResourceSaver.save(res, tres_path)
						print("Converted: ", res_path, " -> ", tres_path)
					else:
						print("Failed to load: ", res_path)
			file_name = dir.get_next()
	else:
		print("Error accessing path: ", path)
