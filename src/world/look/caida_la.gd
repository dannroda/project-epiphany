@tool
extends Node3D
## Luz que entra por un hueco e ilumina el piso de abajo, con polvo que cae. El origen es el centro del hueco a la altura del piso.

## Medidas del hueco en XZ (m).
@export var size := Vector2(2.0, 2.0):
	set(value):
		size = value
		if is_node_ready():
			_fit()

@onready var dust: GPUParticles3D = $Polvo


func _ready() -> void:
	_fit()


func _fit() -> void:
	var box := dust.process_material as ParticleProcessMaterial
	box.emission_box_extents = Vector3(size.x * 0.4, box.emission_box_extents.y, size.y * 0.4)
	dust.amount = clampi(int(size.x * size.y * 1.5), 8, 60)
