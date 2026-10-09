class_name FileSelect
extends UiScreen
## Selección de partida (mockup FileSelect): 3 ranuras, Copiar y Borrar. Copiar y Borrar son subestados de esta
## pantalla; atrás vuelve al modo normal antes de cerrarla.

signal chosen(slot: int, empty: bool)

enum Mode { PLAY, COPY_FROM, COPY_TO, DELETE }

const SCENE_PATH := "res://src/ui/title/file_select.tscn"
const HEADINGS := {
	Mode.PLAY: "Elegí una partida",
	Mode.COPY_FROM: "¿Qué partida copiás?",
	Mode.COPY_TO: "¿En qué ranura la copiás?",
	Mode.DELETE: "¿Qué partida borrás?",
}

var mode := Mode.PLAY
var initial_slot := 0
var _copy_from := -1

@onready var heading: Label = %Heading
@onready var cards: Array[SlotCard] = [%Slot1, %Slot2, %Slot3]
@onready var copy_button: Button = %Copy
@onready var delete_button: Button = %Delete
@onready var hints: HintBar = %Hints


static func open(slot: int) -> FileSelect:
	var screen: FileSelect = load(SCENE_PATH).instantiate()
	screen.initial_slot = slot
	MenuStack.push(screen)
	return screen


func _ready() -> void:
	for card in cards:
		card.pressed.connect(_on_card.bind(card))
	copy_button.pressed.connect(_set_mode.bind(Mode.COPY_FROM))
	delete_button.pressed.connect(_set_mode.bind(Mode.DELETE))
	_set_mode(Mode.PLAY)


func focus_default() -> void:
	cards[clampi(initial_slot, 0, cards.size() - 1)].grab_focus()


func cancel() -> bool:
	if mode == Mode.PLAY:
		return false
	_set_mode(Mode.PLAY)
	return true


func refresh() -> void:
	var any_used := false
	for card in cards:
		card.show_summary(SaveManager.slot_summary(card.slot))
		any_used = any_used or not card.summary.is_empty()
	copy_button.disabled = not any_used
	delete_button.disabled = not any_used


func _set_mode(new_mode: Mode) -> void:
	mode = new_mode
	heading.text = HEADINGS[mode]
	hints.hints = [[&"ui_accept", "Jugar"], [&"ui_cancel", "Volver"]] if mode == Mode.PLAY else [[&"ui_accept", "Elegir"], [&"ui_cancel", "Cancelar"]]
	copy_button.visible = mode == Mode.PLAY
	delete_button.visible = mode == Mode.PLAY
	refresh()
	var focused := get_viewport().gui_get_focus_owner()
	if not focused is SlotCard:
		focus_default()


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
			elif empty:
				SaveManager.copy_slot(_copy_from, card.slot)
				_set_mode(Mode.PLAY)
			else:
				var from := _copy_from
				ConfirmDialog.ask("¿Reemplazar la partida %d con la %d?" % [card.slot + 1, from + 1], "Reemplazar").answered.connect(func(yes: bool) -> void:
					if yes:
						SaveManager.copy_slot(from, card.slot)
					_set_mode(Mode.PLAY))
		Mode.DELETE:
			if empty:
				Feel.sfx(&"deny", Vector3.ZERO)
				return
			ConfirmDialog.ask("¿Borrar la partida %d? No se puede deshacer." % (card.slot + 1), "Borrar").answered.connect(func(yes: bool) -> void:
				if yes:
					SaveManager.delete_slot(card.slot)
				_set_mode(Mode.PLAY))
