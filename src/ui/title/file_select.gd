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
	Mode.PLAY: "Elegí una partida",
	Mode.NEW: "¿Dónde empezás la partida?",
	Mode.COPY_FROM: "¿Qué partida copiás?",
	Mode.COPY_TO: "¿En qué ranura la copiás?",
	Mode.DELETE: "¿Qué partida borrás?",
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
			hints.hints = [[&"ui_accept", "Jugar"], [&"ui_cancel", "Volver"]]
		Mode.NEW:
			hints.hints = [[&"ui_accept", "Empezar"], [&"ui_cancel", "Volver"]]
		_:
			hints.hints = [[&"ui_accept", "Elegir"], [&"ui_cancel", "Cancelar"]]
	copy_button.visible = mode == Mode.PLAY
	delete_button.visible = mode == Mode.PLAY
	refresh()
	var focused := get_viewport().gui_get_focus_owner()
	if not (focused is SlotCard and focused.visible):
		focus_default()


func _name(slot: int) -> String:
	return "el guardado automático" if slot == SaveManager.AUTO_SLOT else "la partida %d" % slot


func _on_card(card: SlotCard) -> void:
	var empty := card.summary.is_empty()
	match mode:
		Mode.PLAY:
			chosen.emit(card.slot, empty)
		Mode.NEW:
			if empty:
				chosen.emit(card.slot, true)
				return
			ConfirmDialog.ask("¿Empezar de cero en la partida %d? Se pierde lo guardado ahí." % card.slot, "Sobrescribir").answered.connect(func(yes: bool) -> void:
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
				ConfirmDialog.ask("¿Reemplazar la partida %d con %s?" % [card.slot, _name(from)], "Reemplazar").answered.connect(func(yes: bool) -> void:
					if yes:
						SaveManager.copy_slot(from, card.slot)
					_set_mode(Mode.PLAY))
		Mode.DELETE:
			if empty:
				Feel.sfx(&"deny", Vector3.ZERO)
				return
			ConfirmDialog.ask("¿Borrar %s? No se puede deshacer." % _name(card.slot), "Borrar").answered.connect(func(yes: bool) -> void:
				if yes:
					SaveManager.delete_slot(card.slot)
				_set_mode(Mode.PLAY))
