extends PausePage
## Pestaña Sistema de la pausa (mockups Pause_System, Pause_System_Save y Pause_System_Load): Guardar, Cargar,
## Opciones y Volver al título; a la derecha los controles básicos del dispositivo en uso (Y/T cambia de vista).
## Guardar pisa siempre la partida cargada; Cargar elige entre el último checkpoint (la Auto, si es de esta partida)
## y lo último guardado a mano. Atrás vuelve de esos paneles a los controles.

signal hints_changed

enum Section { CONTROLS, SAVE, LOAD }

var accept_label := "HINT_ACCEPT"
var extra_hints: Array = []

var _section := Section.CONTROLS
var _load_slot := -1

@onready var save_item: Button = %Save
@onready var load_item: Button = %Load
@onready var last_saved: Label = %LastSaved
@onready var view: ControlsView = %View
@onready var view_title: Label = %ViewTitle
@onready var toggle_icon: TextureRect = %ToggleIcon
@onready var toggle_label: Label = %ToggleLabel
@onready var panels: Dictionary[Section, Control] = {Section.CONTROLS: %ControlsPanel, Section.SAVE: %SavePanel, Section.LOAD: %LoadPanel}
@onready var save_card: SlotCard = %SaveCard
@onready var save_question: Label = %SaveQuestion
@onready var load_auto: SlotCard = %LoadAuto
@onready var load_slot: SlotCard = %LoadSlot
@onready var load_question: Label = %LoadQuestion


func _ready() -> void:
	save_item.pressed.connect(_show_section.bind(Section.SAVE))
	load_item.pressed.connect(_show_section.bind(Section.LOAD))
	%Options.pressed.connect(OptionsScreen.open.bind(true))
	%ToTitle.pressed.connect(_to_title)
	%SaveConfirm.pressed.connect(_save)
	%SaveCancel.pressed.connect(cancel)
	%LoadConfirm.pressed.connect(_load)
	%LoadCancel.pressed.connect(cancel)
	for card: SlotCard in [load_auto, load_slot]:
		card.focus_entered.connect(_choose_load.bind(card))
		card.pressed.connect(%LoadConfirm.grab_focus)
	view.device_changed.connect(_paint_view.unbind(1))
	InputDevice.input_device_changed.connect(_on_input_device_changed)
	visibility_changed.connect(_on_visibility_changed)
	view.use_current_device()
	_refresh_last_saved()


func focus_default() -> void:
	if _section != Section.CONTROLS:
		_show_section(Section.CONTROLS)
	save_item.grab_focus()


func cancel() -> bool:
	if _section == Section.CONTROLS:
		return false
	var back := save_item if _section == Section.SAVE else load_item
	_show_section(Section.CONTROLS)
	back.grab_focus()
	return true


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and _section == Section.CONTROLS and event.is_action_pressed(&"ui_toggle_view"):
		view.toggle()
		get_viewport().set_input_as_handled()


func _show_section(section: Section) -> void:
	_section = section
	for key in panels:
		panels[key].visible = key == section
	save_item.set_pressed_no_signal(section == Section.SAVE)
	load_item.set_pressed_no_signal(section == Section.LOAD)
	match section:
		Section.SAVE:
			var slot := SaveManager.current_slot
			_show_card(save_card, slot)
			save_question.text = tr("SYSTEM_SAVE_QUESTION").format({slot = slot})
			%SaveConfirm.grab_focus()
		Section.LOAD:
			var auto := SaveManager.slot_summary(SaveManager.AUTO_SLOT)
			load_auto.visible = not auto.is_empty() and auto.origin == SaveManager.current_slot
			%CheckpointTitle.visible = load_auto.visible
			load_auto.show_summary(auto if load_auto.visible else {})
			_show_card(load_slot, SaveManager.current_slot)
			(load_auto if load_auto.visible else load_slot).grab_focus()
	_paint_view()


func _show_card(card: SlotCard, slot: int) -> void:
	card.slot = slot
	card.number.text = str(slot)
	card.show_summary(SaveManager.slot_summary(slot))


func _choose_load(card: SlotCard) -> void:
	_load_slot = card.slot
	load_question.text = "SYSTEM_LOAD_QUESTION_AUTO" if card == load_auto else "SYSTEM_LOAD_QUESTION_SLOT"


func _save() -> void:
	SaveManager.save_game()
	_refresh_last_saved()
	cancel()


func _load() -> void:
	if _load_slot < 0 or not SaveManager.has_save(_load_slot):
		Feel.sfx(&"deny", Vector3.ZERO)
		return
	MenuStack.clear()
	SceneFlow.with_fade(SaveManager.load_game.bind(_load_slot))


func _to_title() -> void:
	ConfirmDialog.ask(tr("SYSTEM_TITLE_QUESTION"), "SYSTEM_TO_TITLE").answered.connect(_on_to_title_answered)


func _on_to_title_answered(yes: bool) -> void:
	if yes:
		SceneFlow.quit_to_title()


func _refresh_last_saved() -> void:
	var summary := SaveManager.slot_summary(SaveManager.current_slot)
	last_saved.visible = not summary.is_empty()
	if summary.is_empty():
		return
	var minutes := int(Time.get_unix_time_from_system() - summary.timestamp) / 60
	var ago := tr("SYSTEM_AGO_NOW") if minutes < 1 else tr("SYSTEM_AGO_MIN").format({n = minutes}) if minutes < 60 \
			else tr("SYSTEM_AGO_HOURS").format({n = minutes / 60})
	last_saved.text = tr("SYSTEM_LAST_SAVED").format({place = save_card.place_text(summary.location), ago = ago})


func _paint_view() -> void:
	view_title.text = tr("CONTROLS_BASIC") + " · " + tr("CONTROLS_GAMEPAD" if view.gamepad else "CONTROLS_KEYBOARD")
	toggle_icon.texture = InputPrompts.icon_for_current(&"ui_toggle_view")
	toggle_label.text = "CONTROLS_SEE_KEYBOARD" if view.gamepad else "CONTROLS_SEE_GAMEPAD"
	extra_hints = [[&"ui_toggle_view", "CONTROLS_HINT_KEYBOARD" if view.gamepad else "CONTROLS_HINT_GAMEPAD"]] \
			if _section == Section.CONTROLS else []
	accept_label = "HINT_ACCEPT"
	hints_changed.emit()


func _on_input_device_changed(_device: int) -> void:
	view.use_current_device()
	_paint_view()


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		_refresh_last_saved()
