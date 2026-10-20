extends SceneTree
## Hornea la navmesh del overworld (las colisiones del grupo navmesh_source: GridMap y Terreno) en levels/nav/overworld_navmesh.tres,
## sin islas arriba de las paredes (WallTops, como el Bake del editor).
## godot --headless --path . --script res://tools/bake_overworld_nav.gd
## Otro nivel: … --script res://tools/bake_overworld_nav.gd -- chullpa (levels/chullpa.tscn → levels/nav/chullpa_navmesh.tres)

var _level_path := "res://levels/%s.tscn" % _level_name()
var _out := "res://levels/nav/%s_navmesh.tres" % _level_name()

var _level: Node3D
var _frames := 0


static func _level_name() -> String:
	var args := OS.get_cmdline_user_args()
	return args[0] if not args.is_empty() else "overworld"


func _process(_delta: float) -> bool:
	if _level == null:
		load("res://src/world/nav/wall_tops.gd").register()
		_level = (load(_level_path) as PackedScene).instantiate()
		root.add_child(_level)
		return false
	_frames += 1
	if _frames < 3:
		return false
	var region := _level.get_node("NavigationRegion3D") as NavigationRegion3D
	var navmesh := region.navigation_mesh.duplicate() as NavigationMesh
	region.navigation_mesh = navmesh
	region.bake_navigation_mesh(false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out.get_base_dir()))
	var uid := ResourceLoader.get_resource_uid(_out) if ResourceLoader.exists(_out) else ResourceUID.INVALID_ID
	if uid == ResourceUID.INVALID_ID and FileAccess.file_exists(_out):
		var header := RegEx.create_from_string('uid="(uid://[a-z0-9]+)"').search(FileAccess.open(_out, FileAccess.READ).get_line())
		uid = ResourceUID.text_to_id(header.get_string(1)) if header else uid
	var err := ResourceSaver.save(navmesh, _out)
	if err == OK and uid != ResourceUID.INVALID_ID:
		ResourceSaver.set_uid(_out, uid)
	print("bake_overworld_nav %s: %s · %d vértices, %d polígonos" % [_level_name(), error_string(err), navmesh.get_vertices().size(), navmesh.get_polygon_count()])
	quit(0 if err == OK else 1)
	return true
