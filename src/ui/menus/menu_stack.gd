# Autoload
extends CanvasLayer
## Máquina de estados de la UI: una pila de pantallas (autómata de pila). Solo la de arriba recibe input y foco;
## las de abajo quedan desactivadas (y ocultas si la de arriba las cubre). Con alguna abierta, el juego queda en pausa.
## Las pantallas pueden ser `UiScreen` o cualquier Control (caja de texto, item get): se leen sus propiedades si las tienen.

signal changed

const PAUSE_MENU := preload("res://src/ui/menus/pause_menu.tscn")
const MAP_PAGE := 2

var _stack: Array[Control] = []
## Estado raíz que no es de la pila (la pantalla de título): queda desactivado mientras haya algo encima.
var _base: Control
var _focus_memory: Dictionary[Control, Control] = {}


func _ready() -> void:
	layer = 50
	process_mode = PROCESS_MODE_ALWAYS


func is_open() -> bool:
	return not _stack.is_empty()


func top() -> Control:
	return _stack.back() if is_open() else null


## La pantalla raíz se desregistra sola al salir del árbol.
func set_base(screen: Control) -> void:
	_base = screen
	screen.tree_exiting.connect(func() -> void:
		if _base == screen:
			_base = null)


func push(screen: Control) -> void:
	var covered := top() if is_open() else _base
	if covered:
		_focus_memory[covered] = get_viewport().gui_get_focus_owner()
		covered.process_mode = PROCESS_MODE_DISABLED
		if screen.get(&"hides_below") != false:
			covered.hide()
		if covered.has_method(&"screen_covered"):
			covered.screen_covered()
	_stack.append(screen)
	screen.process_mode = PROCESS_MODE_ALWAYS
	add_child(screen)
	get_tree().paused = true
	if screen.has_method(&"screen_enter"):
		screen.screen_enter()
	_focus(screen)
	changed.emit()


func pop() -> void:
	if not is_open():
		return
	var screen: Control = _stack.pop_back()
	_focus_memory.erase(screen)
	if screen.has_method(&"screen_exit"):
		screen.screen_exit()
	screen.queue_free()
	if not is_open():
		get_tree().paused = false
	var uncovered := top() if is_open() else _base
	if uncovered:
		uncovered.process_mode = PROCESS_MODE_ALWAYS if is_open() else PROCESS_MODE_INHERIT
		uncovered.show()
		if uncovered.has_method(&"screen_uncovered"):
			uncovered.screen_uncovered()
		var remembered: Control = _focus_memory.get(uncovered)
		if is_instance_valid(remembered) and uncovered.is_ancestor_of(remembered):
			remembered.grab_focus()
		else:
			_focus(uncovered)
	changed.emit()


## Cierra todas las pantallas (al salir al título o cambiar de escena).
func clear() -> void:
	while is_open():
		pop()


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
		return
	var screen := top()
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		if screen.has_method(&"cancel") and screen.cancel():
			return
		if screen.get(&"modal") != true:
			pop()
	elif event.is_action_pressed(&"pause") or event.is_action_pressed(&"map"):
		get_viewport().set_input_as_handled()
		if screen.get(&"closes_with_pause") == true:
			pop()


func _focus(screen: Control) -> void:
	if screen.has_method(&"focus_default"):
		screen.focus_default.call_deferred()


## No se pausa sin player vivo (pantallas de carga, muerte, título).
func _can_pause() -> bool:
	var player := get_tree().get_first_node_in_group(&"player")
	return player != null and not player.get(&"is_dead")
