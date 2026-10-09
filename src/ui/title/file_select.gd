class_name FileSelect
extends Control
## Selección de partida (mockup FileSelect): 3 ranuras, Copiar y Borrar (con confirmación).

signal chosen(slot: int, empty: bool)
signal closed

enum Mode { PLAY, COPY_FROM, COPY_TO, DELETE }

const HEADINGS := {
	Mode.PLAY: "Elegí una partida",
	Mode.COPY_FROM: "¿Qué partida copiás?",
	Mode.COPY_TO: "¿En qué ranura la copiás?",
	Mode.DELETE: "¿Qué partida borrás?",
}

var mode := Mode.PLAY
var _heading: Label
var _slots: VBoxContainer
var _hints: HintBar
var _copy_button: Button
var _delete_button: Button
var _confirm: Control
var _copy_from := -1


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("#0b0d10")
	background.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(background)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	column.offset_left = 100
	column.offset_right = -100
	column.offset_top = 56
	column.offset_bottom = -56
	column.add_theme_constant_override(&"separation", 28)
	add_child(column)
	_heading = Label.new()
	_heading.theme_type_variation = &"Title"
	_heading.add_theme_font_size_override(&"font_size", 36)
	column.add_child(_heading)
	_slots = VBoxContainer.new()
	_slots.add_theme_constant_override(&"separation", 18)
	column.add_child(_slots)
	var spacer := Control.new()
	spacer.size_flags_vertical = SIZE_EXPAND_FILL
	column.add_child(spacer)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override(&"separation", 14)
	column.add_child(bottom)
	_copy_button = _bar_button("Copiar")
	_copy_button.pressed.connect(func() -> void: _set_mode(Mode.COPY_FROM))
	bottom.add_child(_copy_button)
	_delete_button = _bar_button("Borrar")
	_delete_button.pressed.connect(func() -> void: _set_mode(Mode.DELETE))
	bottom.add_child(_delete_button)
	var gap := Control.new()
	gap.size_flags_horizontal = SIZE_EXPAND_FILL
	bottom.add_child(gap)
	_hints = HintBar.new()
	bottom.add_child(_hints)
	_set_mode(Mode.PLAY)


func focus_slot(slot: int) -> void:
	(_slots.get_child(clampi(slot, 0, SaveManager.SLOTS - 1)) as Control).grab_focus.call_deferred()


func _set_mode(new_mode: Mode) -> void:
	mode = new_mode
	_heading.text = HEADINGS[mode]
	_hints.hints = [[&"ui_accept", "Jugar"], [&"ui_cancel", "Volver"]] if mode == Mode.PLAY else [[&"ui_accept", "Elegir"], [&"ui_cancel", "Cancelar"]]
	_copy_button.visible = mode == Mode.PLAY
	_delete_button.visible = mode == Mode.PLAY
	_rebuild()


func _rebuild() -> void:
	var focused := 0
	var owner_focus := get_viewport().gui_get_focus_owner()
	if owner_focus is SlotCard:
		focused = (owner_focus as SlotCard).slot
	for child in _slots.get_children():
		_slots.remove_child(child)
		child.queue_free()
	var any_used := false
	for slot in SaveManager.SLOTS:
		var card := SlotCard.new(slot, SaveManager.slot_summary(slot))
		any_used = any_used or not card.summary.is_empty()
		card.pressed.connect(_on_card.bind(card))
		_slots.add_child(card)
	_copy_button.disabled = not any_used
	_delete_button.disabled = not any_used
	focus_slot(focused)


func _on_card(card: SlotCard) -> void:
	var empty := card.summary.is_empty()
	match mode:
		Mode.PLAY:
			chosen.emit(card.slot, empty)
		Mode.COPY_FROM:
			if empty:
				Feel.sfx(&"deny", Vector3.ZERO)
				return
			_copy_from = card.slot
			_set_mode(Mode.COPY_TO)
		Mode.COPY_TO:
			if card.slot == _copy_from:
				Feel.sfx(&"deny", Vector3.ZERO)
				return
			if empty:
				SaveManager.copy_slot(_copy_from, card.slot)
				_set_mode(Mode.PLAY)
			else:
				_ask("¿Reemplazar la partida %d con la %d?" % [card.slot + 1, _copy_from + 1], "Reemplazar", func() -> void:
					SaveManager.copy_slot(_copy_from, card.slot)
					_set_mode(Mode.PLAY))
		Mode.DELETE:
			if empty:
				Feel.sfx(&"deny", Vector3.ZERO)
				return
			_ask("¿Borrar la partida %d? No se puede deshacer." % (card.slot + 1), "Borrar", func() -> void:
				SaveManager.delete_slot(card.slot)
				_set_mode(Mode.PLAY))


## Cartel de confirmación: la opción segura (Cancelar) arranca con el foco.
func _ask(question: String, confirm_label: String, on_confirm: Callable) -> void:
	_confirm = PanelContainer.new()
	_confirm.name = "Confirm"
	_confirm.theme_type_variation = &"MenuFrame"
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 18)
	_confirm.add_child(box)
	var label := Label.new()
	label.text = question
	label.add_theme_font_size_override(&"font_size", 22)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 40)
	box.add_child(row)
	var yes := MenuItem.new()
	yes.name = "Yes"
	yes.label = confirm_label
	yes.font_size = 22
	var no := MenuItem.new()
	no.name = "No"
	no.label = "Cancelar"
	no.font_size = 22
	row.add_child(no)
	row.add_child(yes)
	yes.pressed.connect(func() -> void:
		_close_confirm()
		on_confirm.call())
	no.pressed.connect(func() -> void:
		_close_confirm()
		_set_mode(Mode.PLAY))
	add_child(_confirm)
	_confirm.position = (size - _confirm.get_combined_minimum_size()) / 2.0
	_slots.process_mode = PROCESS_MODE_DISABLED
	no.grab_focus.call_deferred()


func _close_confirm() -> void:
	if is_instance_valid(_confirm):
		_confirm.queue_free()
	_confirm = null
	_slots.process_mode = PROCESS_MODE_INHERIT


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if _confirm:
		_close_confirm()
		_set_mode(Mode.PLAY)
	elif mode != Mode.PLAY:
		_set_mode(Mode.PLAY)
	else:
		closed.emit()


func _bar_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override(&"font_size", 18)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#151920")
	normal.border_color = Color("#3a4250")
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(10)
	normal.content_margin_left = 22
	normal.content_margin_right = 22
	normal.content_margin_top = 10
	normal.content_margin_bottom = 10
	var focus := normal.duplicate() as StyleBoxFlat
	focus.border_color = Color("#d9a441")
	for style in [&"normal", &"hover", &"pressed", &"disabled"]:
		button.add_theme_stylebox_override(style, normal)
	button.add_theme_stylebox_override(&"focus", focus)
	button.add_theme_color_override(&"font_focus_color", Color("#d9a441"))
	return button
