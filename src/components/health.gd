class_name Health
extends Node

signal changed(current: int, max_value: int)
signal damaged(amount: int)
signal died

@export var max_health: int = 12
@export var invulnerability_time: float = 0.8

var current: int
var _invulnerable_left: float = 0.0 ## Con delta, así la pausa no la consume
var _ward_left := 0.0


func _ready() -> void:
	current = max_health


func _physics_process(delta: float) -> void:
	_invulnerable_left = maxf(_invulnerable_left - delta, 0.0)
	_ward_left = maxf(_ward_left - delta, 0.0)


func is_invulnerable() -> bool:
	return _invulnerable_left > 0.0


func is_full() -> bool:
	return current >= max_health


## Invulnerable por un tiempo sin recibir daño (i-frames del roll).
## Nueva vida máxima, llena (al cargar una partida o reaparecer).
func reset(max_value: int) -> void:
	max_health = max_value
	current = max_value
	changed.emit(current, max_health)


## Vida máxima y actual a la vez (la del player viene de GameState).
func restore(max_value: int, current_value: int) -> void:
	max_health = max_value
	current = clampi(current_value, 0, max_value)
	changed.emit(current, max_health)


func make_invulnerable(seconds: float) -> void:
	_invulnerable_left = maxf(_invulnerable_left, seconds)


## Bendición (agua bendita): por un tiempo el daño recibido se reduce a la mitad (redondeando hacia arriba).
func ward(seconds: float) -> void:
	_ward_left = maxf(_ward_left, seconds)


func is_warded() -> bool:
	return _ward_left > 0.0


func ward_left() -> float:
	return _ward_left


func damage(amount: int, ignore_invulnerability := false) -> bool:
	if current <= 0 or (is_invulnerable() and not ignore_invulnerability):
		return false
	if is_warded():
		amount = ceili(amount / 2.0)
	current = maxi(current - amount, 0)
	_invulnerable_left = invulnerability_time
	damaged.emit(amount)
	changed.emit(current, max_health)
	if current == 0:
		died.emit()
	return true


func heal(amount: int) -> void:
	current = mini(current + amount, max_health)
	changed.emit(current, max_health)
