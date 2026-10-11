class_name AreaZone
extends Area3D
## Zona del overworld: al entrar el player, el HUD muestra su nombre (solo si viene de otra zona).

static var _current: AreaZone

@export var display_name: String = ""
## Estilo del terreno orgánico en la zona (STYLES de tools/blender/build_terreno_organico.py): necropolis, laguna, cumbre,
## explanada, cardonal o quebrada; vacío, el de siempre.
@export var terrain_style: StringName = &""


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 | 2
	monitorable = false
	body_entered.connect(func(body: Node3D) -> void:
		if body is PlayerCharacter:
			GameState.visit_zone(name)
		if body is PlayerCharacter and _current != self:
			_current = self
			if not display_name.is_empty():
				get_tree().call_group(&"hud", &"show_area_name", tr(display_name)))


## Si el punto (en XZ) cae dentro de la zona.
func contains(point: Vector3) -> bool:
	var shape := get_node_or_null(^"CollisionShape3D") as CollisionShape3D
	if shape == null or not shape.shape is BoxShape3D:
		return false
	var local := shape.global_transform.affine_inverse() * point
	var half := (shape.shape as BoxShape3D).size / 2.0
	return absf(local.x) <= half.x and absf(local.z) <= half.z


## Rectángulo de la zona en XZ del mundo.
func bounds() -> Rect2:
	var shape := get_node_or_null(^"CollisionShape3D") as CollisionShape3D
	if shape == null or not shape.shape is BoxShape3D:
		return Rect2(Vector2(global_position.x, global_position.z), Vector2.ZERO)
	var size := (shape.shape as BoxShape3D).size
	var center := shape.global_position
	return Rect2(center.x - size.x / 2.0, center.z - size.z / 2.0, size.x, size.z)


func is_visited() -> bool:
	return GameState.visited_zones.has(name)


func _exit_tree() -> void:
	if _current == self:
		_current = null
