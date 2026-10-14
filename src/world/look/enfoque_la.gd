extends Node
## Desenfoque de maqueta que sigue a la cámara (padre): nítido en el piso aunque se acerque al mostrar algo.
## Lo que está en el grupo TALL (los jefes altos) queda nítido hasta su metadata focus_height.

const TALL := &"enfoque_alto"

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
	var near := distance - near_margin
	for node in get_tree().get_nodes_in_group(TALL):
		var tall := node as Node3D
		if tall and tall.is_visible_in_tree():
			var top := tall.global_transform * Vector3(0, float(tall.get_meta(&"focus_height", 0.0)), 0)
			near = minf(near, (top - cam.global_position).dot(forward) - 0.5)
	attributes.dof_blur_near_distance = maxf(near, 0.5)
	attributes.dof_blur_far_distance = distance + far_margin
