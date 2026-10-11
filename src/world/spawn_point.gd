class_name SpawnPoint
extends Marker3D
## Dónde aparece el player. Si es checkpoint, al tocarlo pasa a ser el punto de reaparición.

const GROUP := &"spawn_points"

@export var id: StringName = &"start"
@export var checkpoint := false


## El área `Checkpoint` viene en spawn_point.tscn; un Marker3D suelto con este script es solo un punto de aparición.
func _ready() -> void:
	add_to_group(GROUP)
	var area := get_node_or_null(^"Checkpoint") as Area3D
	if area == null:
		return
	area.monitoring = checkpoint
	if checkpoint:
		area.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group(&"player") and GameState.spawn_point != id:
		GameState.spawn_point = id
		Log.info(&"world", "Checkpoint:", id)


## El punto con ese id en la escena actual; si no hay, el primero que encuentre.
static func find(tree: SceneTree, spawn_id: StringName) -> SpawnPoint:
	var points := tree.get_nodes_in_group(GROUP)
	for point: SpawnPoint in points:
		if point.id == spawn_id:
			return point
	return points[0] if not points.is_empty() else null
