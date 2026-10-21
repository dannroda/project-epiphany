extends Node
## Desenfoque de maqueta que sigue a la cámara del viewport: nítido en el piso aunque se acerque al mostrar algo.
## Lo que está en el grupo TALL (los jefes altos) queda nítido hasta su metadata focus_height.
## El desenfoque cercano solo se prende en un acercamiento o con algo TALL en cuadro y en la sala de la cámara (las otras
## salas y pisos no se ven): en una sala común no hay nada tan cerca de la cámara y la pasada costaba igual (15.23).

const TALL := &"enfoque_alto"
## Metros de más alrededor de lo TALL al ver si está en cuadro: el cuerpo es más ancho que la línea del pie a la cabeza.
const TALL_MARGIN := 3.0

@export var near_margin := 7.0
@export var far_margin := 2.5


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var target := cam.get("target_node") as Node3D
	var attributes := cam.attributes as CameraAttributesPractical
	if target == null or attributes == null:
		return
	var forward := -cam.global_basis.z
	var distance := (target.global_position.y - cam.global_position.y) / minf(forward.y, -0.01)
	var near := distance - near_margin
	var needed: bool = cam.get("revealing") == true
	var room := cam.get("room") as Room
	var anywhere: bool = room == null or cam.get("transitioning") == true
	for node in get_tree().get_nodes_in_group(TALL):
		var tall := node as Node3D
		if tall and tall.is_visible_in_tree():
			var top := tall.global_transform * Vector3(0, float(tall.get_meta(&"focus_height", 0.0)), 0)
			near = minf(near, (top - cam.global_position).dot(forward) - 0.5)
			if anywhere or room.contains(tall.global_position, TALL_MARGIN):
				needed = needed or _in_view(cam, tall.global_position, top)
	attributes.dof_blur_near_enabled = needed
	attributes.dof_blur_near_distance = maxf(near, 0.5)
	attributes.dof_blur_far_distance = distance + far_margin


## Si algo de lo que va del pie a la cabeza (con TALL_MARGIN de radio) entra en el cuadro.
func _in_view(cam: Camera3D, foot: Vector3, top: Vector3) -> bool:
	var center := (foot + top) / 2.0
	var radius := foot.distance_to(top) / 2.0 + TALL_MARGIN
	for plane in cam.get_frustum():
		if plane.distance_to(center) > radius:
			return false
	return true
