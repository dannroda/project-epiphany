extends "res://tests/test_case.gd"

const LANGUAGES := ["es", "en"]
const PREFIXES := ["BOSS_", "COMMON_", "ENDING_", "EQUIP_", "FILE_", "GAMEOVER_", "HINT_", "HUD_", "ITEM_", "ITEMGET_",
	"ITEMS_", "LANGUAGE_", "MAP_", "OPTIONS_", "PAUSE_", "PLACE_", "PROMPT_", "SYSTEM_", "TITLE_"]
const SCAN_DIRS := ["res://src", "res://player", "res://data", "res://levels"]
const NO_ENGLISH_DIALOGUE := ["test_tablets.dialogue"]


func _translation(language: String) -> Translation:
	return load("res://translations/%s.po" % language)


## Claves (sin contexto) de un idioma, incluidas las del plural.
func _keys(language: String) -> PackedStringArray:
	var keys := PackedStringArray()
	var text := FileAccess.get_file_as_string("res://translations/%s.po" % language)
	for found in RegEx.create_from_string("(?m)^msgid(?:_plural)? \"([A-Z][A-Z0-9_]+)\"").search_all(text):
		keys.append(found.get_string(1))
	return keys


func _files(dir: String, out: PackedStringArray) -> void:
	for file in DirAccess.get_files_at(dir):
		if file.get_extension() in ["gd", "tscn", "tres"]:
			out.append(dir.path_join(file))
	for sub in DirAccess.get_directories_at(dir):
		_files(dir.path_join(sub), out)


func test_every_language_has_the_same_keys() -> void:
	var spanish := _keys("es")
	assert_true(spanish.size() > 100, "hay claves en español (%d)" % spanish.size())
	for language in LANGUAGES:
		var keys := _keys(language)
		for key in spanish:
			assert_true(keys.has(key), "%s.po tiene %s" % [language, key])
		for key in keys:
			assert_true(spanish.has(key), "%s de %s.po está en es.po" % [key, language])


func test_every_key_used_in_the_game_exists() -> void:
	var known := _keys("es")
	var files := PackedStringArray()
	for dir in SCAN_DIRS:
		_files(dir, files)
	var literal := RegEx.create_from_string("\"([A-Z][A-Z0-9]*_[A-Z0-9_]+)\"")
	var used := 0
	for path in files:
		for found in literal.search_all(FileAccess.get_file_as_string(path)):
			var key := found.get_string(1)
			if PREFIXES.any(func(prefix: String) -> bool: return key.begins_with(prefix)):
				used += 1
				assert_true(known.has(key), "%s (en %s) tiene traducción" % [key, path])
	assert_true(used > 150, "se encontraron las claves en uso (%d)" % used)
	for item: ItemData in Items.database.items:
		for suffix in ["_NAME", "_DESC", "_GOT"]:
			assert_true(known.has("ITEM_%s%s" % [String(item.id).to_upper(), suffix]), "%s tiene %s" % [item.id, suffix])


func test_every_dialogue_line_is_in_english() -> void:
	var english := _translation("en")
	var lines := 0
	for file in DirAccess.get_files_at("res://data/dialogue"):
		if file.get_extension() != "dialogue" or file in NO_ENGLISH_DIALOGUE:
			continue
		var resource: DialogueResource = load("res://data/dialogue/" + file)
		for id in resource.lines:
			var line: Dictionary = resource.lines[id]
			if line.get(&"type") != DMConstants.TYPE_DIALOGUE:
				continue
			lines += 1
			var english_text := english.get_message(line.text, line.get(&"static_id", ""))
			assert_true(english_text != &"", "%s: \"%s\" tiene inglés" % [file, line.text])
			if line.get(&"character", "") != "":
				assert_true(english.get_message(line.character, &"character") != &"", "el personaje %s tiene inglés" % line.character)
	assert_true(lines > 30, "se recorrieron los diálogos (%d líneas)" % lines)


func test_first_launch_asks_the_language_and_it_changes_live() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var settings: Node = tree.root.get_node(^"Settings")
	var menus: Node = tree.root.get_node(^"MenuStack")
	settings.set_value(&"language", "")
	tree.change_scene_to_file("res://src/ui/title/title_screen.tscn")
	await tree.scene_changed
	await tree.process_frame
	await tree.process_frame
	var picker: Control = menus.top()
	assert_true(picker != null and picker.scene_file_path.ends_with("language_select.tscn"), "sin idioma elegido, lo pide antes del título")
	var english := picker.get_node(^"%English") as Button
	english.grab_focus()
	await tree.process_frame
	assert_eq(TranslationServer.get_locale(), "en", "con el foco en English ya se ve en inglés")
	english.pressed.emit()
	await tree.process_frame
	assert_true(not menus.is_open(), "elegido, queda el título")
	assert_eq(settings.get_value(&"language"), "en", "se guarda en las opciones")
	var title := tree.current_scene
	var continue_item := title.get_node(^"%NewGame") as Button
	assert_eq(continue_item.atr(continue_item.text), "New game", "el título sale en inglés")
	settings.set_value(&"language", "es")
	assert_eq(continue_item.atr(continue_item.text), "Nueva partida", "cambiar en Opciones lo cambia en vivo")
	tree.change_scene_to_file("res://src/ui/title/title_screen.tscn")
	await tree.scene_changed
	await tree.process_frame
	assert_true(not menus.is_open(), "con idioma elegido no lo vuelve a pedir")
