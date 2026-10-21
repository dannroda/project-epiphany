extends RefCounted
## Las mallas de los kits LA con ARRAY_FLAG_COMPRESS_ATTRIBUTES (15.24): posiciones, normales y UV en 16 bits, sin
## tangentes (ningún material las usa). Los LODs quedan los mismos.


static func apply(kit: MeshLibrary) -> void:
	for item in kit.get_item_list():
		var mesh := kit.get_item_mesh(item) as ArrayMesh
		if mesh and not range(mesh.get_surface_count()).all(func(s: int) -> bool: return mesh.surface_get_format(s) & Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES):
			kit.set_item_mesh(item, compressed(mesh))


static func compressed(mesh: ArrayMesh) -> ArrayMesh:
	var out := ArrayMesh.new()
	out.resource_name = mesh.resource_name
	out.custom_aabb = mesh.custom_aabb
	for s in mesh.get_surface_count():
		var surface := RenderingServer.mesh_get_surface(mesh.get_rid(), s)
		var index_size: int = surface.get("index_data", PackedByteArray()).size() / maxi(mesh.surface_get_array_index_len(s), 1)
		var lods := {}
		for lod: Dictionary in surface.get("lods", []):
			lods[lod.edge_length] = _indices(lod.index_data, index_size)
		var arrays := mesh.surface_get_arrays(s)
		arrays[Mesh.ARRAY_TANGENT] = null
		out.add_surface_from_arrays(mesh.surface_get_primitive_type(s), arrays, mesh.surface_get_blend_shape_arrays(s), lods, Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES)
		out.surface_set_material(s, mesh.surface_get_material(s))
		out.surface_set_name(s, mesh.surface_get_name(s))
	return out


static func _indices(data: PackedByteArray, size: int) -> PackedInt32Array:
	if size == 4:
		return data.to_int32_array()
	var out := PackedInt32Array()
	out.resize(data.size() / 2)
	for i in out.size():
		out[i] = data.decode_u16(i * 2)
	return out
