extends SceneTree
## Hornea la navmesh del overworld (las colisiones del grupo navmesh_source: GridMap y Terreno) en levels/nav/overworld_navmesh.tres.
## godot --headless --path . --script res://tools/bake_overworld_nav.gd

const LEVEL := "res://levels/overworld.tscn"
const OUT := "res://levels/nav/overworld_navmesh.tres"

var _level: Node3D
var _frames := 0


func _process(_delta: float) -> bool:
	if _level == null:
		_level = (load(LEVEL) as PackedScene).instantiate()
		root.add_child(_level)
		return false
	_frames += 1
	if _frames < 3:
		return false
	var region := _level.get_node("NavigationRegion3D") as NavigationRegion3D
	var navmesh := region.navigation_mesh.duplicate() as NavigationMesh
	region.navigation_mesh = navmesh
	region.bake_navigation_mesh(false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT.get_base_dir()))
	var uid := ResourceLoader.get_resource_uid(OUT) if ResourceLoader.exists(OUT) else ResourceUID.INVALID_ID
	var err := ResourceSaver.save(navmesh, OUT)
	if err == OK and uid != ResourceUID.INVALID_ID:
		ResourceSaver.set_uid(OUT, uid)
	print("bake_overworld_nav: %s · %d vértices, %d polígonos" % [error_string(err), navmesh.get_vertices().size(), navmesh.get_polygon_count()])
	quit(0 if err == OK else 1)
	return true
