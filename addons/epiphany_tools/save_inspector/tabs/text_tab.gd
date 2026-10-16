@tool
extends "tab.gd"

signal error(message: String)

var _text := TextEdit.new()


func _init() -> void:
	name = "Texto"
	add_child(dim_label("El archivo tal cual, sin la sección meta. Aplicar reemplaza la partida con lo que haya acá."))
	_text.size_flags_vertical = SIZE_EXPAND_FILL
	_text.custom_minimum_size.y = 300
	add_child(_text)
	add_child(button("Aplicar", _apply))


func _ready() -> void:
	_text.add_theme_font_override(&"font", get_theme_font(&"source", &"EditorFonts"))


func refresh() -> void:
	var copy := ConfigFile.new()
	copy.parse(cfg.encode_to_text())
	if copy.has_section(SaveKeys.META):
		copy.erase_section(SaveKeys.META)
	_text.text = copy.encode_to_text()


func _apply() -> void:
	var parsed := ConfigFile.new()
	var err := parsed.parse(_text.text)
	if err != OK:
		error.emit("El texto no es un ConfigFile válido (%s)" % error_string(err))
		return
	cfg.clear()
	cfg.parse(_text.text)
	mark_edited()
