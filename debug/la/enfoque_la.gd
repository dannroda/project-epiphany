extends Node
## Desenfoque de maqueta que sigue a la cámara (padre): nítido en el piso aunque se acerque al mostrar algo.

@export var near_margin := 7.0
@export var far_margin := 2.5


func _process(_delta: float) -> void:
	var cam := get_parent() as Camera3D
	var target := cam.get("target_node") as Node3D
	var attributes := cam.attributes as CameraAttributesPractical
	if target == null or attributes == null:
		return
	var forward := -cam.global_basis.z
	var distance := (target.global_position.y - cam.global_position.y) / minf(forward.y, -0.01)
	attributes.dof_blur_near_distance = maxf(distance - near_margin, 0.5)
	attributes.dof_blur_far_distance = distance + far_margin
