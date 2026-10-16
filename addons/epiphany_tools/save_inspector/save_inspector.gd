@tool
extends VBoxContainer

const SaveManagerScript := preload("res://src/save/save_manager.gd")
const TABS: Array[Script] = [
	preload("tabs/player_tab.gd"), preload("tabs/equipment_tab.gd"), preload("tabs/inventory_tab.gd"),
	preload("tabs/flags_tab.gd"), preload("tabs/dungeons_tab.gd"), preload("tabs/compare_tab.gd"),
	preload("tabs/text_tab.gd"),
]
const PLAY_FILE := "user://debug/inspector_play.cfg"
const NEW_GAME := "res://debug/scenarios/start.cfg"
const SECTION_TABS := { SaveKeys.PLAYER: 0, SaveKeys.EQUIPMENT: 1, SaveKeys.INVENTORY: 2, SaveKeys.FLAGS: 3 }
const UNDO_LIMIT := 100

var _files := OptionButton.new()
var _path_pill := Label.new()
var _dirty_pill := Label.new()
var _valid_pill := Label.new()
var _problems_pill := Button.new()
var _status := Label.new()
var _tab_container := TabContainer.new()
var _tabs: Array = []
var _scenario_dialog := ConfirmationDialog.new()
var _scenario_name := LineEdit.new()
var _reload := Button.new()
var _new := Button.new()
var _undo := Button.new()
var _redo := Button.new()
var _play := Button.new()
var _copy := MenuButton.new()
var _stale_pill := Button.new()
var _confirm := ConfirmationDialog.new()
var _on_confirm := Callable()

var _cfg := ConfigFile.new()
var _db: ItemDatabase
var _flags: FlagRegistry
var _path := ""
var _dirty := false
var _problems := PackedStringArray()
## El md5 del archivo cuando se abrió o guardó: si cambia, lo guardó otro (el juego).
var _disk_md5 := ""
var _undo_stack: Array[String] = []
var _redo_stack: Array[String] = []
## El texto de la partida después del último cambio: lo que vuelve con Deshacer.
var _snapshot := ""


func _init() -> void:
	name = "SaveInspector"
	_db = load("res://data/item_database.tres")
	_flags = load("res://data/flag_registry.tres")

	var files_row := HBoxContainer.new()
	_files.size_flags_horizontal = SIZE_EXPAND_FILL
	_files.clip_text = true
	_files.item_selected.connect(func(index: int) -> void: _open(_files.get_item_metadata(index)))
	files_row.add_child(_files)
	_reload.tooltip_text = "Volver a leer la lista y el archivo"
	_reload.pressed.connect(func() -> void:
		for tab in _tabs:
			if tab.has_method(&"reindex"):
				tab.reindex()
		_refresh_files()
		_open(_path))
	files_row.add_child(_reload)
	_undo.tooltip_text = "Deshacer (Ctrl+Z con el foco en el dock)"
	_undo.shortcut = _shortcut(KEY_Z)
	_undo.pressed.connect(_step_history.bind(_undo_stack, _redo_stack))
	files_row.add_child(_undo)
	_redo.tooltip_text = "Rehacer (Ctrl+Shift+Z)"
	_redo.shortcut = _shortcut(KEY_Z, true)
	_redo.pressed.connect(_step_history.bind(_redo_stack, _undo_stack))
	files_row.add_child(_redo)
	for history_button: Button in [_undo, _redo]:
		history_button.shortcut_context = self
		history_button.shortcut_in_tooltip = false
	_new.tooltip_text = "Partida nueva"
	_new.pressed.connect(_new_game)
	files_row.add_child(_new)
	add_child(files_row)

	var pills := HFlowContainer.new()
	for pill in [_path_pill, _dirty_pill, _valid_pill]:
		pills.add_child(pill)
	_dirty_pill.text = "Sin guardar"
	_valid_pill.text = "Válida"
	_problems_pill.flat = true
	_problems_pill.pressed.connect(_show_first_problem)
	pills.add_child(_problems_pill)
	_stale_pill.flat = true
	_stale_pill.text = "Cambió en disco: recargar"
	_stale_pill.tooltip_text = "El juego (u otro) guardó este archivo después de abrirlo. Recargar descarta lo que editaste acá."
	_stale_pill.visible = false
	_stale_pill.pressed.connect(func() -> void: _open(_path))
	pills.add_child(_stale_pill)
	add_child(pills)

	var actions := HBoxContainer.new()
	_play.text = "Jugar"
	_play.size_flags_horizontal = SIZE_EXPAND_FILL
	_play.pressed.connect(_play_current)
	actions.add_child(_play)
	actions.add_child(_button("Guardar", _save))
	actions.add_child(_button("Guardar como…", _ask_scenario_name))
	_copy.text = "Copiar a…"
	_copy.tooltip_text = "Copiar a una ranura del jugador: aparece en Cargar partida"
	_copy.flat = false
	_copy.about_to_popup.connect(_fill_copy_menu)
	_copy.get_popup().id_pressed.connect(_ask_copy)
	actions.add_child(_copy)
	add_child(actions)

	_tab_container.size_flags_vertical = SIZE_EXPAND_FILL
	_tab_container.tab_changed.connect(func(_index: int) -> void: _refresh_tab())
	for tab_script in TABS:
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var tab: Control = tab_script.new()
		tab.size_flags_horizontal = SIZE_EXPAND_FILL
		tab.cfg = _cfg
		tab.db = _db
		tab.flags = _flags
		tab.edited.connect(_on_edited)
		if tab.has_signal(&"error"):
			tab.error.connect(func(message: String) -> void: _set_status(message, true))
		scroll.name = tab.name
		scroll.add_child(tab)
		_tab_container.add_child(scroll)
		_tabs.append(tab)
	add_child(_tab_container)

	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)

	_scenario_dialog.title = "Guardar como escenario"
	_scenario_name.placeholder_text = "nombre (p. ej. pre_boss)"
	_scenario_dialog.add_child(_scenario_name)
	_scenario_dialog.register_text_enter(_scenario_name)
	_scenario_dialog.confirmed.connect(func() -> void: _save_as_scenario(_scenario_name.text.strip_edges()))
	add_child(_scenario_dialog)

	_confirm.confirmed.connect(func() -> void: _on_confirm.call())
	add_child(_confirm)


func _ready() -> void:
	_reload.icon = get_theme_icon(&"Reload", &"EditorIcons")
	_new.icon = get_theme_icon(&"Add", &"EditorIcons")
	_redo.icon = get_theme_icon(&"Redo", &"EditorIcons")
	_undo.icon = get_theme_icon(&"Undo", &"EditorIcons")
	_play.icon = get_theme_icon(&"Play", &"EditorIcons")
	_style_pill(_path_pill, &"font_placeholder_color")
	_style_pill(_dirty_pill, &"warning_color")
	_style_pill(_valid_pill, &"success_color")
	_style_pill(_problems_pill, &"error_color")
	_style_pill(_stale_pill, &"warning_color")
	_refresh_files()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and is_node_ready():
		_refresh_files()
		_check_disk()


func _refresh_files() -> void:
	_files.clear()
	for entry in [[SaveManagerScript.SCENARIO_DIR, "Escenarios"], [SaveManagerScript.SAVE_DIR, "Partidas"]]:
		var files := Array(DirAccess.get_files_at(entry[0])).filter(func(f: String) -> bool: return f.get_extension() == "cfg")
		if files.is_empty():
			continue
		_files.add_separator(entry[1])
		for file: String in files:
			_files.add_item(_slot_label(file.get_basename()))
			_files.set_item_metadata(_files.item_count - 1, String(entry[0]).path_join(file))
	for i in _files.item_count:
		if _files.get_item_metadata(i) == _path:
			_files.select(i)
			return
	if _path.is_empty() and not _dirty:
		for i in _files.item_count:
			if not _files.is_item_separator(i):
				_files.select(i)
				_open(_files.get_item_metadata(i))
				return


func _slot_label(file_name: String) -> String:
	match file_name:
		"slot_%d" % SaveManagerScript.SCENARIO_SLOT:
			return file_name + " · la de los escenarios y Jugar"
		"slot_%d" % SaveManagerScript.AUTO_SLOT:
			return file_name + " · autosave viejo"
	return file_name


func _open(path: String) -> void:
	if path.is_empty():
		return
	var loaded := ConfigFile.new()
	var err := SaveCodec.read(path, loaded)
	if err != OK:
		_set_status("No se pudo abrir %s (%s)" % [path, error_string(err)], true)
		return
	var tampered := SaveCodec.is_tampered(loaded)
	SaveCodec.migrate(loaded)
	_replace_cfg(loaded)
	_path = path
	_dirty = false
	_disk_md5 = FileAccess.get_md5(path)
	_set_status("Partida modificada a mano" if tampered else "", false)
	_after_change()


func _new_game() -> void:
	var loaded := ConfigFile.new()
	SaveCodec.read(NEW_GAME, loaded)
	_replace_cfg(loaded)
	_path = ""
	_disk_md5 = ""
	_files.select(-1)
	_dirty = true
	_set_status("Partida nueva: guardala como escenario", false)
	_after_change()


func _replace_cfg(source: ConfigFile) -> void:
	_cfg.clear()
	_cfg.parse(source.encode_to_text())
	_undo_stack.clear()
	_redo_stack.clear()
	_snapshot = _cfg.encode_to_text()


func _on_edited() -> void:
	_undo_stack.append(_snapshot)
	if _undo_stack.size() > UNDO_LIMIT:
		_undo_stack.pop_front()
	_redo_stack.clear()
	_snapshot = _cfg.encode_to_text()
	_dirty = true
	_after_change()


## Deshacer y Rehacer: saca de `from` el estado al que vuelve y guarda el actual en `to`.
func _step_history(from: Array[String], to: Array[String]) -> void:
	if from.is_empty():
		return
	to.append(_snapshot)
	_snapshot = from.pop_back()
	_cfg.clear()
	_cfg.parse(_snapshot)
	_dirty = true
	_after_change()


func _shortcut(key: Key, shift := false) -> Shortcut:
	var event := InputEventKey.new()
	event.keycode = key
	event.command_or_control_autoremap = true
	event.shift_pressed = shift
	var shortcut := Shortcut.new()
	shortcut.events = [event]
	return shortcut


func _after_change() -> void:
	_problems = SaveCodec.validate(_cfg)
	_path_pill.text = _path if not _path.is_empty() else "(sin archivo)"
	_dirty_pill.visible = _dirty
	_undo.disabled = _undo_stack.is_empty()
	_redo.disabled = _redo_stack.is_empty()
	_stale_pill.visible = _changed_on_disk()
	_valid_pill.visible = _problems.is_empty()
	_problems_pill.visible = not _problems.is_empty()
	_problems_pill.text = "1 problema" if _problems.size() == 1 else "%d problemas" % _problems.size()
	_problems_pill.tooltip_text = "\n".join(_problems)
	_refresh_tab()


func _refresh_tab() -> void:
	var tab = _tabs[_tab_container.current_tab]
	if tab.cfg != null:
		tab.refresh()


func _show_first_problem() -> void:
	if _problems.is_empty():
		return
	var section := _problems[0].get_slice("/", 0)
	_tab_container.current_tab = SECTION_TABS.get(section, _tabs.size() - 1)
	_set_status("\n".join(_problems), true)


func _save() -> void:
	if _path.is_empty():
		_ask_scenario_name()
		return
	var write := _write.bind(_path, not _path.begins_with(SaveManagerScript.SCENARIO_DIR))
	if _changed_on_disk():
		_ask("El archivo cambió en disco desde que lo abriste (¿lo guardó el juego?). Si guardás, se pierde esa versión.", "Pisar", write)
	else:
		write.call()


func _ask_scenario_name() -> void:
	_scenario_name.text = "" if _path.is_empty() else _path.get_file().get_basename()
	_scenario_dialog.popup_centered(Vector2i(320, 0))
	_scenario_name.grab_focus()


func _save_as_scenario(scenario_name: String) -> void:
	if scenario_name.is_empty() or not scenario_name.is_valid_filename():
		_set_status("Nombre de escenario inválido", true)
		return
	_write(SaveManagerScript.SCENARIO_DIR.path_join(scenario_name + ".cfg"), false)
	_refresh_files()


func _write(path: String, keep_backup: bool) -> void:
	var err := SaveCodec.write(_cfg, path, keep_backup)
	if err != OK:
		_set_status("No se pudo guardar %s (%s)" % [path, error_string(err)], true)
		return
	_path = path
	_dirty = false
	_disk_md5 = FileAccess.get_md5(path)
	if path.begins_with("res://"):
		EditorInterface.get_resource_filesystem().scan()
	var warning := "" if _problems.is_empty() else " con %d problemas" % _problems.size()
	_set_status("Guardado%s" % warning, not _problems.is_empty())
	_after_change()


## Sin cambios propios se recarga sola; con cambios, avisa y no la pisa sin preguntar.
func _check_disk() -> void:
	if not _changed_on_disk():
		return
	if _dirty:
		_after_change()
		_set_status("El archivo cambió en disco y tenés cambios sin guardar", true)
	else:
		_open(_path)
		_set_status("Recargada: cambió en disco", false)


func _changed_on_disk() -> bool:
	return not _path.is_empty() and FileAccess.file_exists(_path) and FileAccess.get_md5(_path) != _disk_md5


func _fill_copy_menu() -> void:
	var popup := _copy.get_popup()
	popup.clear()
	for slot in SaveManagerScript.PLAYER_SLOTS:
		var path := _slot_path(slot)
		var label := "Ranura %d · vacía" % slot
		if FileAccess.file_exists(path):
			var local: int = FileAccess.get_modified_time(path) + Time.get_time_zone_from_system().bias * 60
			var t := Time.get_datetime_dict_from_unix_time(local)
			label = "Ranura %d · %02d/%02d %02d:%02d (se pisa)" % [slot, t.day, t.month, t.hour, t.minute]
		popup.add_item(label, slot)
		popup.set_item_disabled(-1, path == _path)


func _ask_copy(slot: int) -> void:
	var copy := _copy_to.bind(slot)
	if FileAccess.file_exists(_slot_path(slot)):
		_ask("La ranura %d ya tiene una partida. ¿La pisás con esta?" % slot, "Pisar", copy)
	else:
		copy.call()


func _copy_to(slot: int) -> void:
	var copy := ConfigFile.new()
	copy.parse(_cfg.encode_to_text())
	copy.set_value(SaveKeys.META, SaveKeys.SLOT, slot)
	var path := _slot_path(slot)
	var err := SaveCodec.write(copy, path, true)
	if err != OK:
		_set_status("No se pudo copiar a la ranura %d (%s)" % [slot, error_string(err)], true)
		return
	_refresh_files()
	_set_status("Copiada a la ranura %d: está en Cargar partida%s" % [slot, " (con lo que no guardaste acá)" if _dirty else ""], false)


func _slot_path(slot: int) -> String:
	return SaveManagerScript.SAVE_DIR + "slot_%d.cfg" % slot


func _ask(text: String, ok_text: String, on_ok: Callable) -> void:
	_confirm.dialog_text = text
	_confirm.ok_button_text = ok_text
	_on_confirm = on_ok
	_confirm.popup_centered(Vector2i(360, 0))


func _play_current() -> void:
	if SaveCodec.write(_cfg, PLAY_FILE, false) != OK:
		_set_status("No se pudo preparar la partida para jugar", true)
		return
	DirAccess.make_dir_recursive_absolute(SaveManagerScript.NEXT_SCENARIO_FILE.get_base_dir())
	var file := FileAccess.open(SaveManagerScript.NEXT_SCENARIO_FILE, FileAccess.WRITE)
	file.store_string(PLAY_FILE)
	file.close()
	EditorInterface.play_main_scene()


func _set_status(text: String, is_error: bool) -> void:
	_status.text = text
	_status.add_theme_color_override(&"font_color",
			get_theme_color(&"error_color" if is_error else &"font_placeholder_color", &"Editor"))


func _style_pill(pill: Control, color_name: StringName) -> void:
	var color := get_theme_color(color_name, &"Editor")
	var box := StyleBoxFlat.new()
	box.bg_color = Color(color, 0.18)
	box.set_corner_radius_all(10)
	box.set_content_margin_all(2)
	box.content_margin_left = 8
	box.content_margin_right = 8
	for style in [&"normal", &"hover", &"pressed", &"focus"]:
		pill.add_theme_stylebox_override(style, box)
	pill.add_theme_color_override(&"font_color", color)
	pill.add_theme_color_override(&"font_hover_color", color)
	pill.add_theme_font_size_override(&"font_size", 12)


func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	return button
