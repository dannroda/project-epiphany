class_name BossBar
extends RefCounted
## Lo que muestra la barra de jefe del HUD (Boss, ArenaFight): el nombre, cuánto le queda (0..1) y la fase (0 = sin fases).

var display_name: String
var changed: Signal
var fraction: Callable
var _phase: Callable


func _init(name: String, changed_signal: Signal, fraction_of: Callable, phase_of := Callable()) -> void:
	display_name = name
	changed = changed_signal
	fraction = fraction_of
	_phase = phase_of


func phase() -> int:
	return _phase.call() if _phase.is_valid() else 0
