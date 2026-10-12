extends "res://tests/test_case.gd"
## Cada portal de levels/ lleva a una escena que existe y que tiene su SpawnPoint de llegada; los niveles con SpawnPoint
## tienen uid, que es lo que guarda el save (11.88).

const LEVELS := "res://levels/"


func test_every_portal_reaches_an_existing_spawn() -> void:
	var checked := 0
	var spawns := {}
	for file in DirAccess.get_files_at(LEVELS):
		if not file.ends_with(".tscn"):
			continue
		var level := (load(LEVELS + file) as PackedScene).instantiate()
		for portal: Portal in level.find_children("*", "Portal", true, false):
			if not portal.travels:
				continue
			checked += 1
			var where := "%s/%s" % [file, level.get_path_to(portal)]
			assert_true(ResourceLoader.exists(portal.target_scene), "%s: la escena %s existe" % [where, portal.target_scene])
			if not ResourceLoader.exists(portal.target_scene):
				continue
			if not spawns.has(portal.target_scene):
				spawns[portal.target_scene] = _spawn_ids(portal.target_scene)
			assert_true(portal.target_spawn in spawns[portal.target_scene], "%s: %s tiene el punto %s" % [where, portal.target_scene.get_file(), portal.target_spawn])
		level.free()
	assert_true(checked > 0, "hay portales para revisar")


func test_every_level_with_spawn_points_has_a_uid() -> void:
	for file in DirAccess.get_files_at(LEVELS):
		if file.ends_with(".tscn") and not _spawn_ids(LEVELS + file).is_empty():
			assert_true(ResourceLoader.get_resource_uid(LEVELS + file) != ResourceUID.INVALID_ID, "%s tiene uid" % file)


func _spawn_ids(path: String) -> Array[StringName]:
	var ids: Array[StringName] = []
	var level := (load(path) as PackedScene).instantiate()
	for point: SpawnPoint in level.find_children("*", "SpawnPoint", true, false):
		ids.append(point.id)
	level.free()
	return ids
