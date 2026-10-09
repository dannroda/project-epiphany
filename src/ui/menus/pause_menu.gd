extends UiScreen
## Menú de pausa: pestañas Equipo, Ítems, Mapa y Sistema. %Pages (TabContainer sin barra) tiene las páginas y %Tabs
## (TabBar, entre los prompts de Q/E) sus títulos.

const HINTS := [[&"ui_cancel", "Cerrar"], [[&"ui_tab_left", &"ui_tab_right"], "Pestaña"]]

@onready var pages: TabContainer = %Pages
@onready var tabs: TabBar = %Tabs
@onready var hints: HintBar = %Hints
@onready var prev_key: TextureRect = %PrevKey
@onready var next_key: TextureRect = %NextKey

var current := 0


func _ready() -> void:
	InputDevice.input_device_changed.connect(func(_d: int) -> void: _update_hints())
	tabs.tab_changed.connect(func(tab: int) -> void:
		if tab != current:
			show_page(tab))
	show_page(0)


func show_page(index: int) -> void:
	current = wrapi(index, 0, pages.get_tab_count())
	pages.current_tab = current
	tabs.current_tab = current
	focus_default()
	_update_hints()


func focus_default() -> void:
	var page := pages.get_child(current)
	if page.has_method(&"focus_default"):
		page.focus_default()
		return
	for control in page.find_children("*", "Control", true, false):
		if (control as Control).focus_mode == FOCUS_ALL and (control as Control).is_visible_in_tree():
			(control as Control).grab_focus()
			return


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_tab_left"):
		show_page(current - 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_tab_right"):
		show_page(current + 1)
		get_viewport().set_input_as_handled()


func _update_hints() -> void:
	prev_key.texture = InputPrompts.icon_for_current(&"ui_tab_left")
	next_key.texture = InputPrompts.icon_for_current(&"ui_tab_right")
	var page := pages.get_child(current)
	var extra = page.get(&"extra_hints")
	var accept = page.get(&"accept_label")
	var accept_label: String = accept if accept is String else "Usar"
	var all: Array = extra if extra is Array else []
	if not accept_label.is_empty():
		all = all + [[&"ui_accept", accept_label]]
	hints.hints = all + HINTS
