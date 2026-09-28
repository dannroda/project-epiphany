class_name EquippableItem
extends Node3D

@onready var hit_box: Area3D = $HitBox
@export var character: PlayerCharacter
@export var two_handed: bool = false
@export var pushback: float = 10.0
@export var targeting_range: float = 12.0 # Rango de fijado de esta arma
@onready var collision: CollisionShape3D = $HitBox/CollisionShape3D

func _ready() -> void:
	collision.shape = collision.shape.duplicate(true)

func _on_hit_box_body_entered(body: Node3D) -> void:
	if body == character:
		return

	var push_dir := body.global_position - character.global_position
	push_dir.y = 0
	
	if push_dir.is_zero_approx():
		push_dir = -character.global_transform.basis.z
	else:
		push_dir = push_dir.normalized()

	var knockback_vector := (push_dir * pushback) + (Vector3.UP * 4.0)


	if body.has_method("trigger_hit"):
		body.trigger_hit()
	elif body.has_method("take_hit"):
		body.take_hit(10, knockback_vector)

	if body is RigidBody3D:
		body.apply_central_impulse(knockback_vector)
	elif body is CharacterBody3D and body.has_method("apply_knockback"):
		body.apply_knockback(knockback_vector)
		print_rich("[color=Green]%s[/color] force transfered from [color=Orange]%s[/color] to [color=Yellow]%s[/color]" % [knockback_vector, name, body.name])

func enable(_enable: bool) -> void:
	if _enable:
		collision.debug_color = Color.GREEN
	else:
		collision.debug_color = Color.RED
	hit_box.monitoring = _enable
