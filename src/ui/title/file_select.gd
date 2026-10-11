class_name FileSelect
extends UiScreen
## Selección de partida (mockup FileSelect): la ranura Auto arriba, 3 del jugador, Copiar y Borrar. Copiar y Borrar
## son subestados de esta pantalla; atrás vuelve al modo normal antes de cerrarla. En modo NEW (Nueva partida) se
## elige dónde empezar: la Auto no se ofrece y una ranura ocupada pide confirmar.

## `fresh`: empezar de cero en `slot`; si no, cargarla.
signal chosen(slot: int, fresh: bool)

enum Mode { PLAY, NEW, COPY_FROM, COPY_TO, DELETE }

const SCENE_PATH := "res://src/ui/title/file_select.tscn"
const HEADINGS := {
	Mode.PLAY: "FILE_HEADING_PLAY",
	Mode.NEW: "FILE_HEADING_NEW",
	Mode.COPY_FROM: "FILE_HEADING_COPY_FROM",
	Mode.COPY_TO: "FILE_HEADING_COPY_TO",
	Mode.DELETE: "FILE_HEADING_DELETE",
}

var start_mode := Mode.PLAY
var mode := Mode.PLAY
var _copy_from := -1

@onready var heading: Label = %Heading
@onready var auto_card: SlotCard = %Auto
@onready var cards: Array[SlotCard] = [%Auto, %Slot1, %Slot2, %Slot3]
@onready var copy_button: Button = %Copy
@onready var delete_button: Button = %Delete
@onready var hints: HintBar = %Hints


static func open(start := Mode.PLAY) -> FileSelect:
	var screen: FileSelect = load(SCENE_PATH).instantiate()
	screen.start_mode = start
	MenuStack.push(screen)
	return screen


func _ready() -> void:
	for card in cards:
		card.pressed.connect(_on_card.bind(card))
	copy_button.pressed.connect(_set_mode.bind(Mode.COPY_FROM))
	delete_button.pressed.connect(_set_mode.bind(Mode.DELETE))
	_set_mode(start_mode)


## La más reciente para cargar; la primera libre para empezar.
func focus_default() -> void:
	var slot := SaveManager.latest_slot()
	if mode == Mode.NEW or slot < 0:
		slot = SaveManager.PLAYER_SLOTS[0]
		for player_slot in SaveManager.PLAYER_SLOTS:
			if not SaveManager.has_save(player_slot):
				slot = player_slot
				break
	for card in cards:
		if card.slot == slot and card.visible:
			card.grab_focus()
			return
	cards[1].grab_focus()


func cancel() -> bool:
	if mode == start_mode or mode == Mode.PLAY:
		return false
	_set_mode(start_mode)
	return true


func refresh() -> void:
	var any_used := false
	for card in cards:
		card.show_summary(SaveManager.slot_summary(card.slot))
		any_used = any_used or not card.summary.is_empty()
	auto_card.visible = not auto_card.summary.is_empty() and mode not in [Mode.NEW, Mode.COPY_TO]
	copy_button.disabled = not any_used
	delete_button.disabled = not any_used


func _set_mode(new_mode: Mode) -> void:
	mode = new_mode
	heading.text = HEADINGS[mode]
	match mode:
		Mode.PLAY:
			hints.hints = [[&"ui_accept", "FILE_HINT_PLAY"], [&"ui_cancel", "HINT_BACK"]]
		Mode.NEW:
			hints.hints = [[&"ui_accept", "FILE_HINT_START"], [&"ui_cancel", "HINT_BACK"]]
		_:
			hints.hints = [[&"ui_accept", "FILE_HINT_CHOOSE"], [&"ui_cancel", "HINT_CANCEL"]]
	copy_button.visible = mode == Mode.PLAY
	delete_button.visible = mode == Mode.PLAY
	refresh()
	var focused := get_viewport().gui_get_focus_owner()
	if not (focused is SlotCard and focused.visible):
		focus_default()


## La pregunta de `key`, o su variante _AUTO si `from` es la ranura Auto.
func _question(key: String, slot: int, from := -1) -> String:
	if from == SaveManager.AUTO_SLOT or (from < 0 and slot == SaveManager.AUTO_SLOT):
		key += "_AUTO"
	return tr(key).format({slot = slot, from = from})


func _on_card(card: SlotCard) -> void:
	var empty := card.summary.is_empty()
	match mode:
		Mode.PLAY:
			chosen.emit(card.slot, empty)
		Mode.NEW:
			if empty:
				chosen.emit(card.slot, true)
				return
			ConfirmDialog.ask(_question("FILE_CONFIRM_OVERWRITE", card.slot), "FILE_OVERWRITE").answered.connect(func(yes: bool) -> void:
				if yes:
					chosen.emit(card.slot, true))
		Mode.COPY_FROM:
			if empty:
				Feel.sfx(&"deny", Vector3.ZERO)
				return
			_copy_from = card.slot
			_set_mode(Mode.COPY_TO)
		Mode.COPY_TO:
			if card.slot == _copy_from:
				Feel.sfx(&"deny", Vector3.ZERO)
			elif empty:
				SaveManager.copy_slot(_copy_from, card.slot)
				_set_mode(Mode.PLAY)
			else:
				var from := _copy_from
				ConfirmDialog.ask(_question("FILE_CONFIRM_REPLACE", card.slot, from), "FILE_REPLACE").answered.connect(func(yes: bool) -> void:
					if yes:
						SaveManager.copy_slot(from, card.slot)
					_set_mode(Mode.PLAY))
		Mode.DELETE:
			if empty:
				Feel.sfx(&"deny", Vector3.ZERO)
				return
			ConfirmDialog.ask(_question("FILE_CONFIRM_DELETE", card.slot), "FILE_DELETE").answered.connect(func(yes: bool) -> void:
				if yes:
					SaveManager.delete_slot(card.slot)
				_set_mode(Mode.PLAY))
