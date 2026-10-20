class_name Counter
extends Node
## Contraataque (11.34, Wind Waker): con un enemigo fijado, en los últimos `window` segundos de su aviso la espada
## destella y atacar lo esquiva y le pega por la espalda (estado Countering). Se aprende en la piedra de la Pradera.
## Mientras la ventana está abierta el mundo va a `slow_scale`, salvo que se apague en Opciones.

signal opened(target: Node3D)
signal closed

const LEARNED := &"ow_tech_counter"
const SLOW_SETTING := &"counter_slow"
const OPEN_STATES: Array[StringName] = [&"Idle", &"Moving", &"Attacking"]

@export var player: PlayerCharacter
@export var window := 0.35
@export var slow_scale := 0.5
## El destello de la espada: clips glint y RESET.
@export var glint: AnimationPlayer
## El botón de ataque sobre el objetivo.
@export var prompt: Sprite3D

## El enemigo cuyo golpe se puede contraatacar ahora; null con la ventana cerrada.
var target: Node3D
var _spent: Node3D


func is_open() -> bool:
	return target != null


## Lo usa Countering: cierra la ventana y no la vuelve a abrir para ese mismo aviso.
func spend() -> Node3D:
	var hit := target
	_spent = hit
	_close()
	return hit


func _physics_process(_delta: float) -> void:
	var found := _find()
	if found == target:
		return
	if target:
		_close()
	if found:
		_open(found)


func _exit_tree() -> void:
	TimeScale.release(_reason())


func _find() -> Node3D:
	var current := player.targeting.current
	if current == null or not is_instance_valid(current) or not current.has_method(&"strike_in"):
		return null
	var left: float = current.strike_in()
	if left == INF and current == _spent:
		_spent = null
	if current == _spent or left > window or left < 0.0 or not GameState.get_flag(LEARNED):
		return null
	var state := player.movement_state.get_active_state()
	if state == null or state.name not in OPEN_STATES:
		return null
	return current


func _open(found: Node3D) -> void:
	target = found
	glint.play(&"glint")
	prompt.texture = InputPrompts.icon_for(&"attack", player)
	prompt.show()
	if Settings.get_value(SLOW_SETTING):
		TimeScale.hold(_reason(), slow_scale)
	opened.emit(found)


func _close() -> void:
	target = null
	glint.play(&"RESET")
	prompt.hide()
	TimeScale.release(_reason())
	closed.emit()


func _reason() -> StringName:
	return StringName("counter_hint_%d" % player.controls.slot)
