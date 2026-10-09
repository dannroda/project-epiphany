extends "res://tests/test_case.gd"


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
		if name in ["Linux", "Windows"]:
			assert_true("debug/scenarios/*" in excluded and "tests/*" in excluded, "%s no lleva escenarios ni tests" % name)
			assert_eq("plain_saves" in features, false, "%s guarda cifrado" % name)
		elif name.ends_with("(debug)"):
			assert_true("plain_saves" in features, "%s guarda en texto" % name)
	for name in ["Linux", "Windows", "Linux (debug)", "Windows (debug)"]:
		assert_true(found.has(name), "preset %s" % name)


func test_save_key_changed_before_release() -> void:
	var source := FileAccess.get_file_as_string("res://src/save/save_codec.gd")
	assert_eq(source.contains("change-me-before-release"), false, "la clave de guardado ya no es la de ejemplo")
