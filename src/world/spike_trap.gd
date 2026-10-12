@tool
class_name SpikeTrap
extends Node3D
## Pinchos de piso que salen a ritmo: avisan asomando y tintineando, suben de golpe, se quedan arriba y bajan. Arriba
## lastiman a cualquiera (player o enemigo) y el escudo no los frena. Con period 0 quedan siempre arriba.
## Varias trampas con el mismo period y distinto offset arman una ola que se cruza con timing.

const HIDDEN := -0.78
const PEEK := -0.6
const RISE_TIME := 0.06
const FALL_TIME := 0.25

## Segundos de un ciclo entero (abajo → aviso → arriba → abajo); 0 = siempre arriba.
@export var period := 2.4
## Segundos arriba en cada ciclo.
@export var up_time := 0.9
## Desfase dentro del ciclo, en segundos.
@export var offset := 0.0
@export var warn_time := 0.45
@export var damage := 2
@export var knockback := 7.0

var raised := false
var _clock := 0.0
var _warned := false

@onready var spikes: Node3D = $Spikes
@onready var hitbox: Hitbox = $Hitbox


func _ready() -> void:
	spikes.position.y = 0.0 if period <= 0.0 else HIDDEN
	if Engine.is_editor_hint():
		return
	hitbox.hits_all = true
	hitbox.damage_factory = _damage
	_clock = offset
	_set_raised(period <= 0.0, true)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or period <= 0.0:
		return
	_clock = fposmod(_clock + delta, period)
	var down_time := period - up_time
	var up := _clock >= down_time
	var warning := not up and _clock >= down_time - warn_time
	if warning and not _warned:
		_warned = true
		create_tween().tween_property(spikes, ^"position:y", PEEK, 0.12)
		Feel.sfx(&"click", global_position)
	if up != raised:
		_set_raised(up)


## Momento del ciclo en que suben (para alinear la ola en los tests y en el editor).
func time_to_rise() -> float:
	return fposmod(period - up_time - _clock, period) if period > 0.0 else 0.0


func _set_raised(up: bool, instant := false) -> void:
	raised = up
	_warned = false
	hitbox.monitoring = up
	if up:
		hitbox.active_attack = null
	if instant:
		spikes.position.y = 0.0 if up else HIDDEN
		return
	var move := create_tween()
	move.tween_property(spikes, ^"position:y", 0.0 if up else HIDDEN, RISE_TIME if up else FALL_TIME)
	if up:
		Feel.sfx(&"cut", global_position)
		Feel.burst(&"dust", global_position + Vector3.UP * 0.1, Vector3.UP)


func _damage() -> DamageInfo:
	return DamageInfo.make(damage, knockback, self, &"spikes")
