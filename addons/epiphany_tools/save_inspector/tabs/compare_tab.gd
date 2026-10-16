@tool
extends "tab.gd"

const SaveManagerScript := preload("res://src/save/save_manager.gd")
const IGNORED := [SaveKeys.META]

var _other_files := OptionButton.new()
var _list := VBoxContainer.new()
var _other := ConfigFile.new()
var _other_path := ""


func _init() -> void:
	name = "Comparar"
	_other_files.size_flags_horizontal = SIZE_EXPAND_FILL
	_other_files.clip_text = true
	_other_files.item_selected.connect(func(index: int) -> void:
		_other_path = _other_files.get_item_metadata(index)
		refresh())
	add_child(_other_files)
	add_child(_list)


func refresh() -> void:
	_fill_files()
	clear(_list)
	if _other_path.is_empty():
		_list.add_child(dim_label("Elegí otra partida o escenario para ver qué cambia"))
		return
	_other.clear()
	if SaveCodec.read(_other_path, _other) != OK:
		_list.add_child(dim_label("No se pudo leer %s" % _other_path))
		return
	var count := 0
	for section in _sections():
		var keys := _keys(section)
		var header_added := false
		for key in keys:
			var mine: Variant = cfg.get_value(section, key, null)
			var theirs: Variant = _other.get_value(section, key, null)
			if mine == theirs:
				continue
			if not header_added:
				_list.add_child(group_label(section.to_upper()))
				header_added = true
			_list.add_child(_row(section, key, mine, theirs))
			count += 1
	if count == 0:
		_list.add_child(dim_label("Son iguales (sin contar meta)"))
	else:
		var summary := dim_label("%d diferencias con %s" % [count, _other_path.get_file()])
		_list.add_child(summary)
		_list.move_child(summary, 0)


func _fill_files() -> void:
	_other_files.clear()
	_other_files.add_item("(elegí con qué comparar)")
	_other_files.set_item_metadata(0, "")
	for entry in [[SaveManagerScript.SCENARIO_DIR, "Escenarios"], [SaveManagerScript.SAVE_DIR, "Partidas"]]:
		var files := Array(DirAccess.get_files_at(entry[0])).filter(func(f: String) -> bool: return f.get_extension() == "cfg")
		if files.is_empty():
			continue
		_other_files.add_separator(entry[1])
		for file: String in files:
			var path := String(entry[0]).path_join(file)
			_other_files.add_item(file.get_basename())
			_other_files.set_item_metadata(_other_files.item_count - 1, path)
			if path == _other_path:
				_other_files.select(_other_files.item_count - 1)


func _sections() -> PackedStringArray:
	var sections := PackedStringArray()
	for source: ConfigFile in [cfg, _other]:
		for section in source.get_sections():
			if not section in IGNORED and not sections.has(section):
				sections.append(section)
	return sections


func _keys(section: String) -> PackedStringArray:
	var keys := PackedStringArray()
	for source: ConfigFile in [cfg, _other]:
		if source.has_section(section):
			for key in source.get_section_keys(section):
				if not keys.has(key):
					keys.append(key)
	return keys


func _row(section: String, key: String, mine: Variant, theirs: Variant) -> HBoxContainer:
	var row := HBoxContainer.new()
	var names := VBoxContainer.new()
	names.size_flags_horizontal = SIZE_EXPAND_FILL
	names.add_theme_constant_override(&"separation", 0)
	var title := Label.new()
	title.text = key
	title.tooltip_text = _description(section, key)
	title.mouse_filter = MOUSE_FILTER_PASS
	names.add_child(title)
	names.add_child(dim_label("esta: %s · la otra: %s" % [_shown(mine), _shown(theirs)]))
	row.add_child(names)
	var take := button("Usar la otra", func() -> void:
		if theirs == null:
			cfg.erase_section_key(section, key)
		else:
			cfg.set_value(section, key, theirs)
		mark_edited())
	take.tooltip_text = "Copia el valor de la otra a esta"
	row.add_child(take)
	return row


func _description(section: String, key: String) -> String:
	if section != SaveKeys.FLAGS:
		return ""
	for definition in flags.definitions:
		if definition and String(definition.id) == key:
			return definition.description
	return "No registrada"


func _shown(value: Variant) -> String:
	if value == null:
		return "—"
	var text := var_to_str(value)
	return text if text.length() <= 40 else text.left(37) + "…"
