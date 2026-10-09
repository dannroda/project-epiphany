class_name MenuItem
extends Button
## Opción de un menú vertical (título, game over): texto plano y, con foco, dorada y con "▶".

const NORMAL := Color("#efe6d2")
const FOCUSED := Color("#d9a441")
const DISABLED := Color("#6f6a60")

@export var label := "":
	set(value):
		label = value
		_refresh()
@export var font_size := 26


func _ready() -> void:
	flat = true
	focus_mode = FOCUS_ALL
	alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_theme_font_size_override(&"font_size", font_size)
	for state in [&"font_color", &"font_hover_color", &"font_pressed_color"]:
		add_theme_color_override(state, NORMAL)
	for state in [&"font_focus_color", &"font_hover_pressed_color"]:
		add_theme_color_override(state, FOCUSED)
	add_theme_color_override(&"font_disabled_color", DISABLED)
	var empty := StyleBoxEmpty.new()
	for style in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
		add_theme_stylebox_override(style, empty)
	focus_entered.connect(_refresh)
	focus_exited.connect(_refresh)
	mouse_entered.connect(func() -> void:
		if not disabled:
			grab_focus())
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	text = ("▶  " + label) if has_focus() else label
