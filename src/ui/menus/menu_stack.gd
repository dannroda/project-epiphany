# Autoload
extends CanvasLayer
## Pila de pantallas: la de arriba tiene el foco; con alguna abierta el juego queda en pausa.

signal changed

const PAUSE_MENU := preload("res://src/ui/menus/pause_menu.tscn")
const MAP_PAGE := 2

var _stack: Array[Control] = []
var _focus_memory: Dictionary[Control, Control] = {}


func _ready() -> void:
	layer = 50
	process_mode = PROCESS_MODE_ALWAYS


func is_open() -> bool:
	return not _stack.is_empty()


func top() -> Control:
	return _stack.back() if is_open() else null


func push(screen: Control) -> void:
	var previous := top()
	if previous:
		_focus_memory[previous] = get_viewport().gui_get_focus_owner()
		previous.hide()
	_stack.append(screen)
	add_child(screen)
	get_tree().paused = true
	_focus(screen)
	changed.emit()


func pop() -> void:
	if not is_open():
		return
	var screen: Control = _stack.pop_back()
	_focus_memory.erase(screen)
	screen.queue_free()
	var previous := top()
	if previous:
		previous.show()
		var remembered: Control = _focus_memory.get(previous)
		if is_instance_valid(remembered):
			remembered.grab_focus()
		else:
			_focus(previous)
	else:
		get_tree().paused = false
	changed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open():
		if event.is_action_pressed(&"pause") and _can_pause():
			push(PAUSE_MENU.instantiate())
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed(&"map") and _can_pause():
			var menu := PAUSE_MENU.instantiate()
			push(menu)
			menu.show_page(MAP_PAGE)
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause") or event.is_action_pressed(&"map"):
		pop()
		get_viewport().set_input_as_handled()


func _focus(screen: Control) -> void:
	if screen.has_method(&"focus_default"):
		screen.focus_default.call_deferred()


## No se pausa sin player vivo (pantallas de carga, muerte, título).
func _can_pause() -> bool:
	var player := get_tree().get_first_node_in_group(&"player")
	return player != null and not player.get(&"is_dead")
