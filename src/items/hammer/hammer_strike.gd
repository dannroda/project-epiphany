extends Hitbox
## Martillazo (11.191): golpe al piso delante del player durante unos cuadros, con polvo y temblor; todo lo que toca
## es golpe fuerte (DamageInfo.strong). Quien recibe el martillazo queda congelado un instante.

@export var active_frames := 3
@export var stun_time := 0.1

var _frames := 0


func _ready() -> void:
	super()
	landed.connect(func(hurtbox: Hurtbox) -> void: Feel.hit_stop([hurtbox.get_parent()], stun_time))
	Feel.burst(&"dust", global_position + Vector3.UP * 0.1, Vector3.UP)
	Feel.sfx(&"hit_stone", global_position)
	Feel.shake(Feel.settings.shake_give * 1.5)


func _physics_process(delta: float) -> void:
	super(delta)
	_frames += 1
	if _frames == active_frames:
		set_deferred(&"monitoring", false)
	elif _frames > active_frames:
		queue_free()
