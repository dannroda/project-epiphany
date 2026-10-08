extends Node3D
## Planta una grilla de matas de pasto (con algo de desorden) al cargar.

const GRASS := preload("res://src/world/grass.tscn")

@export var columns := 10
@export var rows := 5
@export var spacing := 0.8
@export var jitter := 0.25
@export var random_seed := 1


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	for row in rows:
		for column in columns:
			var grass := GRASS.instantiate() as Node3D
			grass.position = Vector3(column * spacing + rng.randf_range(-jitter, jitter), 0.0, row * spacing + rng.randf_range(-jitter, jitter))
			grass.rotation.y = rng.randf() * TAU
			add_child(grass)
