extends Hitbox
## Un instante de daño en área: lastima a todos (incluido el player), empuja cuerpos físicos y detona otras bombas.

## Lo que tarda el anillo de fuego del piso en abrirse y apagarse.
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
	var light := %Flash as OmniLight3D
	create_tween().tween_property(light, "light_energy", 0.0, 0.3).from(6.0)
	var fireball := %Fireball as MeshInstance3D
	var radius := ($CollisionShape3D.shape as SphereShape3D).radius
	var material := fireball.material_override.duplicate() as StandardMaterial3D
	fireball.material_override = material
	fireball.rotation = Vector3(randf(), randf(), randf()) * TAU
	var grow := create_tween().set_parallel()
	grow.tween_property(fireball, "scale", Vector3.ONE * radius, 0.18).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	grow.tween_property(material, "albedo_color:a", 0.0, 0.35).set_delay(0.08)
	var ring := %AnilloFuego as MeshInstance3D
	grow.tween_method(func(value: float) -> void: ring.set_instance_shader_parameter(&"progress", value), 0.0, 1.0, RING_TIME)


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
