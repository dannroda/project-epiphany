class_name AreaZone
extends Area3D
## Zona del overworld (una o más pantallas) de una `region`; al entrar el player, el HUD muestra el nombre de la región
## solo si viene de otra.

const GROUP := &"area_zones"

## La última zona en la que entró el lead; se olvida al salir del árbol (cambio de escena).
static var _current: AreaZone

## Clave de la zona en las partidas (visitada o no); vacío, el nombre del nodo. Renombrar el nodo no la cambia.
@export var id: StringName = &""
@export var region: ZoneRegion


func _ready() -> void:
	add_to_group(GROUP)
	tree_exiting.connect(func() -> void:
		if _current == self:
			_current = null)
	collision_layer = 0
	collision_mask = 1 | 2
	monitorable = false
	body_entered.connect(func(body: Node3D) -> void:
		if body is PlayerCharacter:
			GameState.visit_zone(key())
		if body == Players.lead() and _current != self:
			var same_region := is_instance_valid(_current) and _current.region == region
			_current = self
			if region and not same_region:
				Hud.events.area_announced.emit(tr(region.display_name)))


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


## Las zonas de la región de persecución del punto; vacío si no cae en ninguna.
static func region_at(tree: SceneTree, point: Vector3) -> Array[AreaZone]:
	var region: Array[AreaZone] = []
	for zone: AreaZone in tree.get_nodes_in_group(GROUP):
		if not zone.chase_key().is_empty() and zone.contains(point):
			for other: AreaZone in tree.get_nodes_in_group(GROUP):
				if other.chase_key() == zone.chase_key():
					region.append(other)
			break
	return region


func region_name() -> String:
	return region.display_name if region else ""


func chase_key() -> StringName:
	return region.chase_key() if region else &""


## El nombre de la región va en el mapa sobre esta zona.
func has_region_label() -> bool:
	return region != null and region.label_zone == key()


func key() -> StringName:
	return id if not id.is_empty() else StringName(name)


func is_visited() -> bool:
	return GameState.visited_zones.has(key())


func _exit_tree() -> void:
	if _current == self:
		_current = null
