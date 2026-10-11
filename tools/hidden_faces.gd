extends RefCounted
## Caras de las paredes que nunca se ven (10.26): la base de cada piedra, pegada al núcleo del muro, y las que
## miran abajo (la cámara y el sol vienen de arriba).

const CORE := 1.0
const SLACK := 0.03


static func strip(mesh: Mesh) -> ArrayMesh:
	var out := ArrayMesh.new()
	for surface in mesh.get_surface_count():
		var tool := SurfaceTool.new()
		tool.append_from(mesh, surface, Transform3D.IDENTITY)
		tool.index()
		var arrays := tool.commit_to_arrays()
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var kept := PackedInt32Array()
		for t in range(0, index.size(), 3):
			var tri := [index[t], index[t + 1], index[t + 2]]
			var normal := (normals[tri[0]] + normals[tri[1]] + normals[tri[2]]).normalized()
			if not _hidden([verts[tri[0]], verts[tri[1]], verts[tri[2]]], normal):
				kept.append_array(tri)
		arrays[Mesh.ARRAY_INDEX] = kept
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out


static func _hidden(tri: Array, normal: Vector3) -> bool:
	if normal.y < -0.9:
		return true
	for axis in [Vector3.AXIS_X, Vector3.AXIS_Z]:
		var side := signf((tri[0] as Vector3)[axis])
		if normal[axis] * side > -0.9:
			continue
		if tri.all(func(p: Vector3) -> bool: return absf(p[axis] * side - CORE) < SLACK):
			return true
	return false
