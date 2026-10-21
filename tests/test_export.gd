extends "res://tests/test_case.gd"

const RELEASE_EXCLUDES := ["tests/*", "debug/*", "tools/*", "levels/test/*"]


func test_presets_keep_debug_content_out_of_release() -> void:
	var cfg := ConfigFile.new()
	assert_eq(cfg.load("res://export_presets.cfg"), OK)
	var found := {}
	for section in cfg.get_sections():
		if not section.begins_with("preset.") or section.ends_with(".options"):
			continue
		var name: String = cfg.get_value(section, "name")
		found[name] = true
		var excluded: String = cfg.get_value(section, "exclude_filter", "")
		var features: String = cfg.get_value(section, "custom_features", "")
		if name in ["Linux", "Windows", "macOS", "Web"]:
			for filter in RELEASE_EXCLUDES:
				assert_true(filter in excluded, "%s no lleva %s" % [name, filter])
			assert_eq("plain_saves" in features, false, "%s guarda cifrado" % name)
		elif name.ends_with("(debug)"):
			assert_true("plain_saves" in features, "%s guarda en texto" % name)
	for name in ["Linux", "Windows", "Linux (debug)", "Windows (debug)"]:
		assert_true(found.has(name), "preset %s" % name)


func test_save_key_changed_before_release() -> void:
	var source := FileAccess.get_file_as_string("res://src/save/save_codec.gd")
	assert_eq(source.contains("change-me-before-release"), false, "la clave de guardado ya no es la de ejemplo")


func test_no_game_file_needs_an_excluded_one() -> void:
	for path: String in ["res://src/ui/title/title_screen.tscn", "res://levels/overworld.tscn", "res://src/flow/scene_flow.tscn"]:
		for dep: String in ResourceLoader.get_dependencies(path):
			var dep_path := dep.get_slice("::", 2) if dep.contains("::") else dep
			if dep_path.begins_with("uid://"):
				dep_path = ResourceUID.uid_to_path(dep_path)
			for prefix in ["res://debug/", "res://tools/", "res://levels/test/"]:
				assert_true(not dep_path.begins_with(prefix), "%s necesita %s, que no se exporta" % [path, dep_path])
