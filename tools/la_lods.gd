extends RefCounted
## LODs de las paredes LA (15.16): con los ladrillos biselados a la distancia de la cámara, la mitad de los triángulos
## no cambia ni un pixel. Las piezas que ya tienen LODs quedan igual.

const NORMAL_MERGE_ANGLE := 25.0


static func apply(kit: MeshLibrary, prefixes: Array) -> void:
	for item in kit.get_item_list():
		var mesh := kit.get_item_mesh(item) as ArrayMesh
		if mesh == null or not prefixes.any(func(prefix: String) -> bool: return kit.get_item_name(item).begins_with(prefix)):
			continue
		if range(mesh.get_surface_count()).any(func(s: int) -> bool: return not RenderingServer.mesh_get_surface(mesh.get_rid(), s).get("lods", []).is_empty()):
			continue
		var source := ImporterMesh.new()
		for s in mesh.get_surface_count():
			source.add_surface(Mesh.PRIMITIVE_TRIANGLES, mesh.surface_get_arrays(s), [], {}, mesh.surface_get_material(s), mesh.surface_get_name(s))
		source.generate_lods(NORMAL_MERGE_ANGLE, 60.0, [])
		var lodded := source.get_mesh()
		lodded.resource_name = mesh.resource_name
		kit.set_item_mesh(item, lodded)
