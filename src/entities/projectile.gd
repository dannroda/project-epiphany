class_name Projectile
extends Hitbox
## Se mueve solo, daña al primer Hurtbox de otro equipo y se rompe (o se clava) contra el mundo.

## A 60 Hz, 24 m/s son 0,4 m por paso: menos que cualquier Hurtbox o pared, así no atraviesa nada.
const MAX_SPEED := 24.0

@export var lifetime: float = 4.0
## Flechas: se quedan clavadas en la pared este rato antes de desaparecer.
@export var stick_time: float = 0.0
@export var burst: StringName = &"sparks"

var velocity: Vector3
## Quién lo disparó (el `source` del daño es el proyectil, para que el bloqueo mire de dónde viene).
var shooter: Node3D
var _damage: DamageInfo
var _stuck := false
var _just_reflected := false


func launch(from: Vector3, initial_velocity: Vector3, info: DamageInfo) -> void:
	global_position = from
	velocity = initial_velocity.limit_length(MAX_SPEED)
	shooter = info.source
	_damage = info
	_damage.source = self
	team = info.team
	damage_factory = func() -> DamageInfo: return _damage
	monitoring = true
	_face_velocity()
	landed.connect(_on_landed)


## El orbe del jefe corrupto (y su estela) en otro color.
func tint(color: Color) -> void:
	$Mesh.set_instance_shader_parameter(&"color", color)
	var trail := $Estela as GPUParticles3D
	trail.process_material = trail.process_material.duplicate()
	(trail.process_material as ParticleProcessMaterial).color = color


## Lo devuelve el escudo espejo: misma velocidad, nueva dirección y nuevo equipo.
func reflect(direction: Vector3, new_team: EntityConfig.Team) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z)
	velocity = (flat if not flat.is_zero_approx() else -velocity).normalized() * velocity.length()
	team = new_team
	_damage.team = new_team
	_just_reflected = true
	_face_velocity()


func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	if not _stuck:
		global_position += velocity * delta


func _on_landed(_hurtbox: Hurtbox) -> void:
	if _just_reflected:
		_just_reflected = false
		return
	queue_free()


## Contra el mundo (paredes, piso, cajas).
func _on_body_entered(body: Node3D) -> void:
	if _stuck or _on_character(body):
		return
	super(body)
	Feel.burst(burst, global_position, -velocity.normalized())
	if stick_time > 0.0 and not body is RigidBody3D:
		_stuck = true
		lifetime = stick_time
		var trail := get_node_or_null(^"Trail") as Trail3D
		if trail:
			Feel.set_trail(trail, false)
		set_deferred(&"monitoring", false)
	else:
		queue_free()


func _face_velocity() -> void:
	if not velocity.is_zero_approx():
		look_at(global_position + velocity, Vector3.UP if absf(velocity.normalized().y) < 0.99 else Vector3.RIGHT)


## Personajes y lo que llevan encima (escudos con colisión): los resuelve su Hurtbox.
func _on_character(body: Node) -> bool:
	var node := body
	while node:
		if node is CharacterBody3D:
			return true
		node = node.get_parent()
	return false
