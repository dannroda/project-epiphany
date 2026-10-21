extends "res://tests/test_case.gd"
## 16.22: lo que se revisa barre la carpeta entera, así un archivo nuevo no queda afuera.


func _files(dir: String, extension := ".tres") -> Array[String]:
	var found: Array[String] = []
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(extension):
			found.append(dir.path_join(file))
	return found


func test_every_level_flag_is_registered() -> void:
	var registry: FlagRegistry = load(FlagRegistry.PATH)
	var checked := 0
	for path in _files("res://levels", ".tscn") + _files("res://levels/test", ".tscn"):
		var root: Node = load(path).instantiate()
		for node in [root] + root.find_children("*", "", true, false):
			for property in node.get_property_list():
				var key: String = property.name
				if key != "flag" and not key.ends_with("_flag"):
					continue
				var id: Variant = node.get(key)
				if id is StringName and id != &"":
					assert_true(registry.has(id), "%s: %s.%s = %s está registrada" % [path.get_file(), node.name, key, id])
					checked += 1
		root.free()
	assert_true(checked > 150, "revisó los flags de los niveles (%d)" % checked)


func test_every_attack_has_its_windows_in_order() -> void:
	var checked := 0
	for path in _files("res://data/attacks") + _files("res://data/boss"):
		var attack := load(path) as AttackData
		if attack == null:
			continue
		assert_true(attack.active_from < attack.active_to and attack.active_to <= attack.cancel_from, "%s: active_from < active_to <= cancel_from" % path.get_file())
		checked += 1
	assert_true(checked >= 5, "revisó los ataques (%d)" % checked)


func test_every_entity_config_loads_with_its_drops() -> void:
	var checked := 0
	for path in _files("res://data/entities"):
		var config := load(path) as EntityConfig
		assert_true(config != null, path.get_file() + " es un EntityConfig")
		if config == null:
			continue
		if config.drops:
			assert_true(not config.drops.entries.is_empty(), path.get_file() + ": sus drops tienen algo")
		checked += 1
	assert_true(checked >= 20, "revisó los configs (%d)" % checked)
