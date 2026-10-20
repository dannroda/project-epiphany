class_name BoxBounds
## El rectángulo XZ del mundo que cubre la caja (CollisionShape3D hijo) de una sala, zona o arena.


static func xz(node: Node3D) -> Rect2:
	var shape := node.get_node_or_null(^"CollisionShape3D") as CollisionShape3D
	if shape == null or not shape.shape is BoxShape3D:
		return Rect2(Vector2(node.global_position.x, node.global_position.z), Vector2.ZERO)
	var size := (shape.shape as BoxShape3D).size
	var center := shape.global_position
	return Rect2(center.x - size.x / 2.0, center.z - size.z / 2.0, size.x, size.z)
