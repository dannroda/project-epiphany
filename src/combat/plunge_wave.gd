extends Hitbox
## La onda del golpe en picada (11.34): unos cuadros al caer, con polvo y temblor; pega con `attack` y hunde las placas
## STRIKE (slam).

@export var attack: AttackData
@export var active_frames := 3

var _frames := 0


func _ready() -> void:
	super()
	active_attack = attack
	_feel.call_deferred()


func _feel() -> void:
	Feel.burst(&"dust", global_position + Vector3.UP * 0.1, Vector3.UP)
	Feel.sfx(&"hit_stone", global_position)
	Feel.shake(Feel.settings.shake_give * 1.2)


func _physics_process(delta: float) -> void:
	super(delta)
	_frames += 1
	if _frames == active_frames:
		set_deferred(&"monitoring", false)
	elif _frames > active_frames:
		queue_free()
