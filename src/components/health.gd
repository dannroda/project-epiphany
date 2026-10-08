class_name Health
extends Node

signal changed(current: int, max_value: int)
signal damaged(amount: int)
signal died

@export var max_health: int = 12
@export var invulnerability_time: float = 0.8

var current: int
var _invulnerable_left: float = 0.0 ## Con delta, así la pausa no la consume


func _ready() -> void:
	current = max_health


func _physics_process(delta: float) -> void:
	_invulnerable_left = maxf(_invulnerable_left - delta, 0.0)


func is_invulnerable() -> bool:
	return _invulnerable_left > 0.0


func is_full() -> bool:
	return current >= max_health


## Invulnerable por un tiempo sin recibir daño (i-frames del roll).
func make_invulnerable(seconds: float) -> void:
	_invulnerable_left = maxf(_invulnerable_left, seconds)


func damage(amount: int) -> bool:
	if current <= 0 or is_invulnerable():
		return false
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
