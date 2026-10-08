class_name Bomb
extends RigidBody3D
## Mecha con parpadeo que se acelera; al final explota. La espada la patea; otra explosión la adelanta.

const EXPLOSION := preload("res://src/items/bomb/explosion.tscn")

@export var fuse := 2.0

@onready var body_mesh: MeshInstance3D = $Body

var _left := 0.0
var _flash := StandardMaterial3D.new()
var _exploded := false


func _ready() -> void:
	add_to_group(&"bombs")
	_left = fuse
	_flash.albedo_color = Color(0.2, 0.2, 0.25)
	_flash.emission_enabled = true
	_flash.emission = Color(1.0, 0.2, 0.1)
	body_mesh.material_override = _flash


func _physics_process(delta: float) -> void:
	_left -= delta
	var urgency := 1.0 - clampf(_left / fuse, 0.0, 1.0)
	var blink := sin(Time.get_ticks_msec() / 1000.0 * lerpf(6.0, 40.0, urgency)) > 0.0
	_flash.emission_energy_multiplier = 2.5 if blink else 0.0
	if _left <= 0.0:
		explode()


## Las explosiones cercanas la adelantan (reacción en cadena).
func detonate() -> void:
	_left = minf(_left, 0.08)


func explode() -> void:
	if _exploded:
		return
	_exploded = true
	var explosion: Node3D = EXPLOSION.instantiate()
	get_parent().add_child(explosion)
	explosion.global_position = global_position
	queue_free()
