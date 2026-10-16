class_name HookPost
extends StaticBody3D
## Poste para el gancho (11.30): la punta se clava acá y el player vuela hasta él, por encima de agua y huecos. Con el
## gancho en un botón se puede fijar (Targeting), y así se alcanza uno más alto o más bajo.

const GROUP := &"hook_posts"
const RING_HEIGHT := 0.9


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(Targeting.GROUP)


func ring() -> Vector3:
	return global_position + Vector3.UP * RING_HEIGHT
