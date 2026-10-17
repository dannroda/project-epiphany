extends Hitbox
## Un instante de daño en área: lastima a todos (incluido el player), empuja cuerpos físicos y detona otras bombas.

## Lo que tarda el anillo de fuego del piso en abrirse y apagarse (el largo del clip "blast").
const RING_TIME := 0.6

@export var damage := 4
@export var knockback := 9.0
## Cuadros de física que queda activa.
@export var active_frames := 3

var _frames := 0


func _ready() -> void:
	super()
	hits_all = true
	damage_factory = _make_damage
	_feel.call_deferred()
	var fireball := %Fireball as MeshInstance3D
	fireball.material_override = fireball.material_override.duplicate()
	fireball.rotation = Vector3(randf(), randf(), randf()) * TAU
	%BlastAnim.play(&"blast")


## Diferido: la escena está ocupada agregando este nodo y no acepta más hijos.
func _feel() -> void:
	Feel.burst(&"explosion", global_position + Vector3.UP * 0.4, Vector3.UP)
	Feel.sfx(&"boom", global_position)
	Feel.shake(Feel.settings.shake_give * 3.0)


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _frames == active_frames:
		set_deferred(&"monitoring", false)
	if _frames > active_frames + ceili(RING_TIME * Engine.physics_ticks_per_second):
		queue_free()


func _make_damage() -> DamageInfo:
	return DamageInfo.make(damage, knockback, self, DamageInfo.EXPLOSIVE)


func _on_body_entered(body: Node3D) -> void:
	if body is Bomb:
		body.detonate()
	super(body)
