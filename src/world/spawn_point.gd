class_name SpawnPoint
extends Marker3D
## Dónde aparece el player. Si es checkpoint, al tocarlo pasa a ser el punto de reaparición.

const GROUP := &"spawn_points"

@export var id: StringName = &"start"
@export var checkpoint := false
@export var checkpoint_radius := 1.5


func _ready() -> void:
	add_to_group(GROUP)
	if checkpoint:
		var area := Area3D.new()
		var shape := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = checkpoint_radius
		shape.shape = sphere
		area.add_child(shape)
		area.collision_layer = 0
		area.body_entered.connect(_on_body_entered)
		add_child(area)


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
