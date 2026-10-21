class_name PracticeDummy
extends StaticBody3D
## Muñeco de práctica de las piedras de técnica (11.34): se puede fijar, aguanta todo y cada `period` segundos avisa un
## golpe de mentira durante `windup` segundos (clip windup, después swing) para practicar el contraataque. No lastima.

signal struck

@export var config: EntityConfig
@export var period := 3.0
@export var windup := 0.9

@onready var anim: AnimationPlayer = %Anim
@onready var hurtbox: Hurtbox = $Hurtbox

var hits := 0
var _clock := 0.0
var _strike_left := INF


func _ready() -> void:
	add_to_group(Targeting.GROUP)
	hurtbox.team = EntityConfig.Team.ENEMY
	hurtbox.hit.connect(_on_hit)


func _physics_process(delta: float) -> void:
	_clock += delta
	if _strike_left != INF:
		_strike_left -= delta
		if _strike_left <= 0.0:
			_strike_left = INF
			anim.play(&"swing")
	elif _clock >= period:
		_clock = 0.0
		_strike_left = windup
		anim.play(&"windup")


## Segundos hasta su golpe de mentira; INF si no avisa (lo lee Counter).
func strike_in() -> float:
	return _strike_left


func _on_hit(_info: DamageInfo) -> void:
	hits += 1
	Feel.burst(&"sparks", global_position + Vector3.UP * 1.1, Vector3.UP)
	struck.emit()
