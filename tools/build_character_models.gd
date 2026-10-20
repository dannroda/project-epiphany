extends SceneTree
## Arma un "Visuals" por personaje (assets/epiphany/personaje_*.glb, pesados al Rig_Medium de KayKit): mallas en .res
## con el material de la paleta y una escena que se cuelga de un ModelController con su Skeleton3D al lado
## (el rig y las animaciones de siempre).
## godot --headless --path . --script res://tools/build_character_models.gd

const OUTPUT := "res://src/entities/models/%s.tscn"
const MESHES := "res://src/entities/models/meshes/%s/"
const SKELETON := NodePath("../../Skeleton3D")
const MATERIAL := preload("res://data/kits/materials/epiphany.tres")
const CHARACTERS := {
	"jugador": "res://assets/epiphany/personaje_jugador.glb",
	"chullpa": "res://assets/epiphany/personaje_chullpa.glb",
	"chullpa_guardian": "res://assets/epiphany/personaje_chullpa_guardian.glb",
	"centinela": "res://assets/epiphany/personaje_centinela.glb",
	"huanca": "res://assets/epiphany/personaje_huanca.glb",
	"guerrero_chullpa": "res://assets/epiphany/personaje_guerrero_chullpa.glb",
	"guerrero_quenoa": "res://assets/epiphany/personaje_guerrero_quenoa.glb",
	"guerrero_totora": "res://assets/epiphany/personaje_guerrero_totora.glb",
	"guerrero_cumbre": "res://assets/epiphany/personaje_guerrero_cumbre.glb",
	"guerrero_templo": "res://assets/epiphany/personaje_guerrero_templo.glb",
	"devoto": "res://assets/epiphany/personaje_devoto.glb",
}
## El rig del proyecto no tiene los huesos de las armas; sus binds pasan a la mano (no pesan en ningún vértice).
const BIND_RENAMES := {"handslot.l": "hand.l", "handslot.r": "hand.r"}
## Mallas con huesos propios que cuelgan de un hueso del rig y se mueven con un SpringBoneSimulator3D: llevan su
## propio Skeleton3D pegado a ese hueso por un BoneAttachment3D, así el Skeleton3D de cada entidad no cambia.
const SPRINGS := {
	"jugador": {"mesh": "trenza", "bone": "head", "stiffness": 1.5, "drag": 0.4, "gravity": 0.6},
}


func _initialize() -> void:
	var failed := false
	for model_name: String in CHARACTERS:
		var err := _build(model_name, CHARACTERS[model_name])
		print("%s: %s" % [model_name, error_string(err)])
		failed = failed or err != OK
	quit(1 if failed else 0)


func _build(model_name: String, source: String) -> Error:
	var folder: String = MESHES % model_name
	DirAccess.make_dir_recursive_absolute(folder)
	var scene: Node = (load(source) as PackedScene).instantiate()
	var skeleton: Skeleton3D = scene.find_children("*", "Skeleton3D", true, false)[0]
	var spring: Dictionary = SPRINGS.get(model_name, {})
	var meshes := skeleton.find_children("*", "MeshInstance3D", true, false)
	var part: MeshInstance3D = meshes.filter(func(m: MeshInstance3D) -> bool: return m.name != spring.get("mesh", "")).front()
	var visuals := Node3D.new()
	visuals.name = "Visuals"
	var skin_path := folder + "skin.tres"
	ResourceSaver.save(_skin(part.skin, spring.get("mesh", "")), skin_path)
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = _save_mesh(part.mesh, MATERIAL, folder + "Body.res")
	body.skin = load(skin_path)
	body.skeleton = SKELETON
	visuals.add_child(body)
	if not spring.is_empty():
		var chain: MeshInstance3D = meshes.filter(func(m: MeshInstance3D) -> bool: return m.name == spring["mesh"]).front()
		visuals.add_child(_spring_chain(skeleton, chain, spring, folder))
	scene.free()
	for node in visuals.find_children("*", "", true, false):
		node.owner = visuals
	var packed := PackedScene.new()
	packed.pack(visuals)
	visuals.free()
	return ResourceSaver.save(packed, OUTPUT % model_name)


func _spring_chain(source: Skeleton3D, part: MeshInstance3D, config: Dictionary, folder: String) -> BoneAttachment3D:
	var mesh_name: String = config["mesh"]
	var attachment := BoneAttachment3D.new()
	attachment.name = mesh_name.capitalize()
	attachment.use_external_skeleton = true
	attachment.external_skeleton = NodePath("../../Skeleton3D")
	attachment.bone_name = config["bone"]
	var anchor := source.get_bone_global_rest(source.find_bone(config["bone"]))
	var skeleton := Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	skeleton.add_bone("root")
	var bones: Array[int] = []
	var skin := part.skin.duplicate() as Skin
	for i in skin.get_bind_count():
		if String(skin.get_bind_name(i)).begins_with(mesh_name):
			bones.append(source.find_bone(skin.get_bind_name(i)))
		else:
			skin.set_bind_name(i, "root")
	bones.sort()
	for bone in bones:
		var index := skeleton.add_bone(source.get_bone_name(bone))
		var parent := skeleton.find_bone(source.get_bone_name(source.get_bone_parent(bone)))
		skeleton.set_bone_parent(index, maxi(parent, 0))
		skeleton.set_bone_rest(index, source.get_bone_rest(bone) if parent > 0 else anchor.affine_inverse() * source.get_bone_global_rest(bone))
		skeleton.reset_bone_pose(index)
	attachment.add_child(skeleton)
	var skin_path := folder + mesh_name + "_skin.tres"
	ResourceSaver.save(skin, skin_path)
	var mesh := MeshInstance3D.new()
	mesh.name = mesh_name.capitalize()
	mesh.mesh = _save_mesh(part.mesh, MATERIAL, folder + mesh_name.capitalize() + ".res")
	mesh.skin = load(skin_path)
	mesh.skeleton = NodePath("..")
	skeleton.add_child(mesh)
	var springs := SpringBoneSimulator3D.new()
	springs.name = "Springs"
	springs.setting_count = 1
	springs.set_root_bone_name(0, skeleton.get_bone_name(1))
	springs.set_end_bone_name(0, skeleton.get_bone_name(skeleton.get_bone_count() - 1))
	springs.set_extend_end_bone(0, true)
	springs.set_stiffness(0, config["stiffness"])
	springs.set_drag(0, config["drag"])
	springs.set_gravity(0, config["gravity"])
	skeleton.add_child(springs)
	return attachment


func _save_mesh(source: Mesh, material: Material, path: String) -> Mesh:
	var mesh := source.duplicate() as ArrayMesh
	for surface in mesh.get_surface_count():
		mesh.surface_set_material(surface, material)
	ResourceSaver.save(mesh, path)
	return load(path)


func _skin(source: Skin, chain := "") -> Skin:
	var skin := source.duplicate() as Skin
	for i in skin.get_bind_count():
		if chain and String(skin.get_bind_name(i)).begins_with(chain):
			skin.set_bind_name(i, "root")
		if BIND_RENAMES.has(String(skin.get_bind_name(i))):
			skin.set_bind_name(i, BIND_RENAMES[String(skin.get_bind_name(i))])
	return skin
