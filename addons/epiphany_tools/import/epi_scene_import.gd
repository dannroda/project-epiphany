@tool
extends EditorScenePostImportPlugin
## Importa los .glb que publica tools/blender (epi.publish) en assets/epiphany/: la paleta compartida en lugar del
## material de Blender, cada malla guardada en assets/epiphany/meshes/<archivo>/<pieza>.res (las partes <archivo>.<parte>.glb
## también ahí) y las custom properties:
## col=box|sphere|capsule|convex en una malla → StaticBody3D; socket en un empty → Marker3D; spring en un hueso → cadena
## de SpringBoneSimulator3D desde ese hueso (el valor es la rigidez); group en cualquier objeto (también -colonly) → ese grupo;
## shadow=off en una malla → no proyecta sombra.
## Una malla <pieza>_col-colonly es la colisión simplificada de <pieza>: su cuerpo va adentro de la malla, como con -col.

const ROOT := "res://assets/epiphany/"
const MESH_DIR := "epiphany/mesh_dir"
const MESHES := "res://assets/epiphany/meshes/%s/"
const MATERIALS := {"paleta": "res://data/kits/materials/epiphany.tres"}
## Custom property material en el objeto: otra variante de la paleta para toda la malla (lo de afuera, con viento).
const TAGGED := {
	"outdoor": "res://data/kits/materials/epiphany_outdoor.tres",
	"wind": "res://data/kits/materials/epiphany_wind.tres",
	"wall": "res://data/kits/materials/epiphany_wall.tres",
}


func _get_import_options(path: String) -> void:
	var ours := path.begins_with(ROOT) and path.get_extension() == "glb"
	add_import_option(MESH_DIR, MESHES % path.get_file().get_slice(".", 0) if ours else "")


func _post_process(scene: Node) -> void:
	var mesh_dir: String = get_option_value(MESH_DIR)
	if mesh_dir.is_empty():
		return
	var saved := {}
	for node: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		_use_palette(node.mesh, _extras(node).get("material", ""))
		if not saved.has(node.mesh):
			saved[node.mesh] = true
			_save_mesh(node, mesh_dir)
		if _extras(node).get("shadow", "") == "off":
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var col: String = _extras(node).get("col", "")
		if not col.is_empty():
			_add_collision(node, col)
	for body: StaticBody3D in scene.find_children("*_col", "StaticBody3D", true, false):
		_attach_collision(body)
	for node: Node in scene.find_children("*", "", true, false):
		var group: String = _extras(node).get("group", "")
		if not group.is_empty():
			node.add_to_group(group, true)
	for node: Node3D in scene.find_children("*", "Node3D", true, false):
		if _extras(node).has("socket") and node.get_class() == "Node3D":
			_to_marker(node)
	for skeleton: Skeleton3D in scene.find_children("*", "Skeleton3D", true, false):
		_add_springs(skeleton)


func _extras(object: Object) -> Dictionary:
	return object.get_meta(&"extras", {})


func _use_palette(mesh: Mesh, tag: String) -> void:
	for surface in mesh.get_surface_count():
		var material := mesh.surface_get_material(surface)
		if material and MATERIALS.has(material.resource_name):
			mesh.surface_set_material(surface, load(TAGGED.get(tag, MATERIALS[material.resource_name])))


func _save_mesh(node: MeshInstance3D, mesh_dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(mesh_dir)
	node.mesh.resource_name = node.name
	var err := ResourceSaver.save(node.mesh, mesh_dir + node.name + ".res")
	if err != OK:
		push_error("epi_scene_import: %s: %s" % [node.name, error_string(err)])


func _add_collision(node: MeshInstance3D, kind: String) -> void:
	var box := node.mesh.get_aabb()
	var shape: Shape3D
	match kind:
		"box":
			shape = BoxShape3D.new()
			shape.size = box.size
		"sphere":
			shape = SphereShape3D.new()
			shape.radius = box.size[box.get_longest_axis_index()] / 2.0
		"capsule":
			shape = CapsuleShape3D.new()
			shape.radius = maxf(box.size.x, box.size.z) / 2.0
			shape.height = maxf(box.size.y, shape.radius * 2.0)
		"convex":
			shape = node.mesh.create_convex_shape()
		_:
			push_error("epi_scene_import: %s: col=%s desconocido" % [node.name, kind])
			return
	var body := StaticBody3D.new()
	body.name = node.name + "_col"
	var collider := CollisionShape3D.new()
	collider.shape = shape
	if kind != "convex":
		collider.position = box.get_center()
	body.add_child(collider)
	node.add_child(body)
	body.owner = node.owner
	collider.owner = node.owner


func _attach_collision(body: StaticBody3D) -> void:
	var mesh := body.get_parent().get_node_or_null(NodePath(String(body.name).trim_suffix("_col"))) as MeshInstance3D
	if mesh == null:
		return
	body.reparent(mesh)
	for node: Node in [body] + body.get_children():
		node.owner = mesh.owner


func _to_marker(node: Node3D) -> void:
	var marker := Marker3D.new()
	marker.name = node.name
	marker.transform = node.transform
	marker.set_meta(&"extras", _extras(node))
	node.replace_by(marker, true)
	node.free()


func _add_springs(skeleton: Skeleton3D) -> void:
	var roots: Array[int] = []
	for bone in skeleton.get_bone_count():
		if skeleton.has_bone_meta(bone, &"extras") and skeleton.get_bone_meta(bone, &"extras").has("spring"):
			roots.append(bone)
	if roots.is_empty():
		return
	var springs := SpringBoneSimulator3D.new()
	springs.name = "Springs"
	springs.setting_count = roots.size()
	for i in roots.size():
		var end := roots[i]
		while not skeleton.get_bone_children(end).is_empty():
			end = skeleton.get_bone_children(end)[0]
		springs.set_root_bone_name(i, skeleton.get_bone_name(roots[i]))
		springs.set_end_bone_name(i, skeleton.get_bone_name(end))
		springs.set_extend_end_bone(i, true)
		springs.set_stiffness(i, float(skeleton.get_bone_meta(roots[i], &"extras")["spring"]))
	skeleton.add_child(springs)
	springs.owner = skeleton.owner
