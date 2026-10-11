extends Hitbox
## Un instante de daño en área: lastima a todos (incluido el player), empuja cuerpos físicos y detona otras bombas.

@export var damage := 4
@export var knockback := 9.0
## Cuadros de física que queda activa.
@export var active_frames := 3

var _frames := 0


func _ready() -> void:
	super()
	hits_all = true
	damage_factory = _make_damage
	Feel.burst(&"explosion", global_position + Vector3.UP * 0.4, Vector3.UP)
	Feel.sfx(&"boom", global_position)
	Feel.shake(Feel.settings.shake_give * 3.0)
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


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _frames == active_frames:
		set_deferred(&"monitoring", false)
	if _frames > active_frames + 20:
		queue_free()


func _make_damage() -> DamageInfo:
	var info := DamageInfo.new()
	info.amount = damage
	info.knockback = knockback
	info.source = self
	info.element = &"explosive"
	return info


func _on_body_entered(body: Node3D) -> void:
	if body is Bomb:
		body.detonate()
	super(body)
