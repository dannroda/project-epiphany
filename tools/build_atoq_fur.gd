extends SceneTree
## Arma el pelo del atoq que se mueve con resortes, como la trenza del jugador: por cada pieza de art/blender/atoq_pelo.json
## (las cadenas de huesos que guarda build_atoq.py) pesa su malla a los huesos y escribe src/entities/atoq/<pieza>.tscn,
## un Skeleton3D con la malla y un SpringBoneSimulator3D con una cadena por mechón, para colgar del nodo de la pieza.
## godot --headless --path . --script res://tools/build_atoq_fur.gd

const CHAINS := "res://art/blender/atoq_pelo.json"
const SOURCE := "res://assets/epiphany/meshes/atoq/%s.res"
const OUTPUT := "res://src/entities/atoq/%s.tscn"
const MESHES := "res://src/entities/atoq/meshes/"
const SPRINGS := {
	"atoq_cola": {"stiffness": 2.5, "drag": 0.5, "gravity": 0.3},
	"atoq_pelo_cuerpo": {"stiffness": 4.0, "drag": 0.45, "gravity": 0.25},
	"atoq_pelo_cabeza": {"stiffness": 4.0, "drag": 0.45, "gravity": 0.25},
}


func _initialize() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CHAINS))
	DirAccess.make_dir_recursive_absolute(MESHES)
	var failed := false
	for piece: String in data:
		var err := _build(piece, _chains(data[piece]))
		print("%s: %s" % [piece, error_string(err)])
		failed = failed or err != OK
	quit(1 if failed else 0)


func _chains(raw: Array) -> Array:
	var chains := []
	for points: Array in raw:
		var chain: Array[Vector3] = []
		for p: Array in points:
			chain.append(Vector3(p[0], p[1], p[2]))
		if chain.size() == 2:
			chain.insert(1, chain[0].lerp(chain[1], 0.5))
		chains.append(chain)
	return chains


func _build(piece: String, chains: Array) -> Error:
	var skeleton := Skeleton3D.new()
	skeleton.name = "Pelo"
	skeleton.add_bone("root")
	var bones := []
	for c in chains.size():
		var chain: Array[Vector3] = chains[c]
		var ids: Array[int] = []
		for k in chain.size():
			var bone := skeleton.add_bone("%s_%d_%d" % [piece.trim_prefix("atoq_"), c, k])
			skeleton.set_bone_parent(bone, ids.back() if k > 0 else 0)
			skeleton.set_bone_rest(bone, Transform3D(Basis(), chain[k] - (chain[k - 1] if k > 0 else Vector3.ZERO)))
			skeleton.reset_bone_pose(bone)
			ids.append(bone)
		bones.append(ids)
	var skin := Skin.new()
	for bone in skeleton.get_bone_count():
		skin.add_named_bind(skeleton.get_bone_name(bone), skeleton.get_bone_global_rest(bone).affine_inverse())
	var skin_path := MESHES + piece + "_skin.tres"
	ResourceSaver.save(skin, skin_path)
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	mesh.mesh = _skinned(load(SOURCE % piece), chains, bones, MESHES + piece + ".res")
	mesh.skin = load(skin_path)
	mesh.skeleton = NodePath("..")
	skeleton.add_child(mesh)
	var springs := SpringBoneSimulator3D.new()
	springs.name = "Springs"
	springs.setting_count = chains.size()
	var config: Dictionary = SPRINGS[piece]
	for c in chains.size():
		springs.set_root_bone_name(c, skeleton.get_bone_name(bones[c].front()))
		springs.set_end_bone_name(c, skeleton.get_bone_name(bones[c].back()))
		springs.set_stiffness(c, config["stiffness"])
		springs.set_drag(c, config["drag"])
		springs.set_gravity(c, config["gravity"])
		springs.set_radius(c, 0.02)
	skeleton.add_child(springs)
	for node in skeleton.find_children("*", "", true, false):
		node.owner = skeleton
	var packed := PackedScene.new()
	packed.pack(skeleton)
	skeleton.free()
	return ResourceSaver.save(packed, OUTPUT % piece)


func _skinned(source: ArrayMesh, chains: Array, bones: Array, path: String) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bone_ids := PackedInt32Array()
		var weights := PackedFloat32Array()
		for v in vertices:
			var hit := _nearest(v, chains)
			var ids: Array[int] = bones[int(hit.x)]
			var k := int(hit.y)
			bone_ids.append_array([ids[k], ids[mini(k + 1, ids.size() - 1)], 0, 0])
			weights.append_array([1.0 - hit.z, hit.z, 0.0, 0.0])
		arrays[Mesh.ARRAY_BONES] = bone_ids
		arrays[Mesh.ARRAY_WEIGHTS] = weights
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(surface, source.surface_get_material(surface))
	ResourceSaver.save(mesh, path)
	return load(path)


## La cadena más cercana a v: Vector3(cadena, segmento, fracción a lo largo del segmento).
func _nearest(v: Vector3, chains: Array) -> Vector3:
	var best := INF
	var hit := Vector3.ZERO
	for c in chains.size():
		var chain: Array[Vector3] = chains[c]
		for k in chain.size() - 1:
			var a := chain[k]
			var ab := chain[k + 1] - a
			var f := clampf((v - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
			var d := v.distance_to(a + ab * f)
			if d < best:
				best = d
				hit = Vector3(c, k, f)
	return hit
