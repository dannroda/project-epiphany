class_name DodgeGhosts
extends Node
## Fantasmas de la pose al esquivar (como el dash de Mega Man Zero): cada `interval` deja una copia congelada que se desvanece.

@export var model: Node3D
@export var ghost_scene: PackedScene
@export var interval := 0.06
@export var lifetime := 0.3
## Mallas del modelo que no van en el fantasma.
@export var skip: Array[Node] = []

var _left := 0.0
var _next := 0.0


func start(duration: float) -> void:
	_left = duration
	_next = 0.0


func _process(delta: float) -> void:
	if _left <= 0.0:
		return
	_left -= delta
	_next -= delta
	if _next <= 0.0:
		_next = interval
		spawn()


func spawn() -> Afterimage:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	var ghost: Afterimage = ghost_scene.instantiate()
	ghost.mesh = _bake()
	scene.add_child(ghost)
	ghost.global_transform = model.global_transform
	ghost.fade_out(lifetime)
	return ghost


func _bake() -> ArrayMesh:
	var result := ArrayMesh.new()
	var to_model := model.global_transform.affine_inverse()
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var piece := node as MeshInstance3D
		if piece in skip or not piece.is_visible_in_tree() or piece.mesh == null:
			continue
		var mesh: Mesh = piece.bake_mesh_from_current_skeleton_pose() if piece.skin != null or piece.skeleton != NodePath() else piece.mesh
		if mesh == null:
			continue
		var xform := to_model * piece.global_transform
		var normals_xform := Transform3D(xform.basis.inverse().transposed(), Vector3.ZERO)
		for surface in mesh.get_surface_count():
			var source := mesh.surface_get_arrays(surface)
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = xform * (source[Mesh.ARRAY_VERTEX] as PackedVector3Array)
			if source[Mesh.ARRAY_NORMAL] != null:
				arrays[Mesh.ARRAY_NORMAL] = normals_xform * (source[Mesh.ARRAY_NORMAL] as PackedVector3Array)
			arrays[Mesh.ARRAY_INDEX] = source[Mesh.ARRAY_INDEX]
			result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result
