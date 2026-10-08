@tool
extends VBoxContainer

signal filter_changed(level: int, channels: PackedStringArray)

const LEVELS: PackedStringArray = ["DEBUG", "INFO", "SUCCESS", "WARNING", "ERROR"]
const MAX_ENTRIES := 5000

var _level := OptionButton.new()
var _channels := LineEdit.new()
var _list := ItemList.new()
var _clear := Button.new()
var _entries: Array[Dictionary] = []
var _colors: Array[Color] = [Color.GRAY, Color.CYAN, Color.GREEN, Color.YELLOW, Color.TOMATO]


func _init() -> void:
	var bar := HBoxContainer.new()
	for level_name in LEVELS:
		_level.add_item(level_name.capitalize())
	_level.tooltip_text = "Nivel mínimo"
	_level.item_selected.connect(func(_i: int) -> void: _on_filter_changed())
	bar.add_child(_level)

	_channels.placeholder_text = "Canales separados por coma (vacío = todos), p. ej. combat, engine"
	_channels.size_flags_horizontal = SIZE_EXPAND_FILL
	_channels.text_submitted.connect(func(_t: String) -> void: _on_filter_changed())
	_channels.focus_exited.connect(_on_filter_changed)
	_channels.clear_button_enabled = true
	_channels.text_changed.connect(func(t: String) -> void:
		if t.is_empty():
			_on_filter_changed())
	bar.add_child(_channels)

	_clear.flat = true
	_clear.tooltip_text = "Borrar el log"
	_clear.pressed.connect(clear_entries)
	bar.add_child(_clear)
	add_child(bar)

	_list.size_flags_vertical = SIZE_EXPAND_FILL
	_list.custom_minimum_size.y = 120
	_list.item_activated.connect(_on_item_activated)
	add_child(_list)


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		_clear.icon = get_theme_icon(&"Clear", &"EditorIcons")
		_colors = [
			get_theme_color(&"font_placeholder_color", &"Editor"),
			get_theme_color(&"font_color", &"Editor"),
			get_theme_color(&"success_color", &"Editor"),
			get_theme_color(&"warning_color", &"Editor"),
			get_theme_color(&"error_color", &"Editor"),
		]
		_rebuild()


func get_filter() -> Array:
	var channels := PackedStringArray()
	for channel in _channels.text.split(",", false):
		channel = channel.strip_edges()
		if not channel.is_empty():
			channels.append(channel)
	return [_level.selected, channels]


func add_entry(level: int, channel: String, text: String, file: String, line: int, time: String) -> void:
	var entry := { "level": level, "channel": channel, "text": text, "file": file, "line": line, "time": time }
	_entries.append(entry)
	if _entries.size() > MAX_ENTRIES:
		var oldest: Dictionary = _entries.pop_front()
		if _list.item_count > 0 and _list.get_item_metadata(0) == oldest:
			_list.remove_item(0)
	if _passes(entry, get_filter()):
		_add_item(entry)
		_list.ensure_current_is_visible()
		_list.get_v_scroll_bar().value = _list.get_v_scroll_bar().max_value


func clear_entries() -> void:
	_entries.clear()
	_list.clear()


func _on_filter_changed() -> void:
	var filter := get_filter()
	_rebuild()
	filter_changed.emit(filter[0], filter[1])


func _rebuild() -> void:
	_list.clear()
	var filter := get_filter()
	for entry in _entries:
		if _passes(entry, filter):
			_add_item(entry)


func _passes(entry: Dictionary, filter: Array) -> bool:
	var channels: PackedStringArray = filter[1]
	return entry.level >= filter[0] and (channels.is_empty() or entry.channel in channels)


func _add_item(entry: Dictionary) -> void:
	var level: int = clampi(entry.level, 0, LEVELS.size() - 1)
	var text: String = entry.text
	var i := _list.add_item("%s  %-7s  %-10s  %s" % [entry.time, LEVELS[level], entry.channel, text.get_slice("\n", 0)])
	_list.set_item_custom_fg_color(i, _colors[level])
	_list.set_item_metadata(i, entry)
	var tooltip := text
	if not String(entry.file).is_empty():
		tooltip += "\n\n%s:%d (doble clic para abrir)" % [entry.file, entry.line]
	_list.set_item_tooltip(i, tooltip)


func _on_item_activated(index: int) -> void:
	var entry: Dictionary = _list.get_item_metadata(index)
	var file: String = entry.file
	if file.begins_with("res://") and ResourceLoader.exists(file):
		var script := load(file) as Script
		if script:
			EditorInterface.edit_script(script, maxi(entry.line, 1), 1)
			EditorInterface.set_main_screen_editor("Script")
