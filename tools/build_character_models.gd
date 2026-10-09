extends SceneTree
## Arma un "Visuals" por personaje KayKit (Rig_Medium): mallas en .res con el material de su textura y una escena
## que se cuelga de un ModelController con su Skeleton3D al lado (el rig y las animaciones de siempre).
## godot --headless --path . --script res://tools/build_character_models.gd

const OUTPUT := "res://src/entities/models/%s.tscn"
const MESHES := "res://src/entities/models/meshes/%s/"
const SKELETON := NodePath("../../Skeleton3D")
const CHARACTERS := {
	"skeleton_minion": ["res://assets/kaykit_skeletons/characters/Skeleton_Minion.glb", "res://assets/kaykit_skeletons/characters/skeleton_texture.png"],
	"skeleton_warrior": ["res://assets/kaykit_skeletons/characters/Skeleton_Warrior.glb", "res://assets/kaykit_skeletons/characters/skeleton_texture.png"],
	"skeleton_rogue": ["res://assets/kaykit_skeletons/characters/Skeleton_Rogue.glb", "res://assets/kaykit_skeletons/characters/skeleton_texture.png"],
	"skeleton_mage": ["res://assets/kaykit_skeletons/characters/Skeleton_Mage.glb", "res://assets/kaykit_skeletons/characters/skeleton_texture.png"],
	"knight": ["res://assets/kaykit_adventure/Characters/gltf/Knight.glb", "res://assets/kaykit_adventure/Characters/gltf/knight_texture.png"],
}
## El rig del proyecto no tiene los huesos de las armas; sus binds pasan a la mano (no pesan en ningún vértice).
const BIND_RENAMES := {"handslot.l": "hand.l", "handslot.r": "hand.r"}


func _initialize() -> void:
	var failed := false
	for model_name: String in CHARACTERS:
		var err := _build(model_name, CHARACTERS[model_name][0], load(CHARACTERS[model_name][1]))
		print("%s: %s" % [model_name, error_string(err)])
		failed = failed or err != OK
	quit(1 if failed else 0)


func _build(model_name: String, source: String, texture: Texture2D) -> Error:
	var folder: String = MESHES % model_name
	DirAccess.make_dir_recursive_absolute(folder)
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.roughness = 1.0
	var material_path := folder + "material.tres"
	ResourceSaver.save(material, material_path)
	material = load(material_path)

	var scene: Node = (load(source) as PackedScene).instantiate()
	var skeleton: Skeleton3D = scene.find_children("*", "Skeleton3D", true, false)[0]
	var visuals := Node3D.new()
	visuals.name = "Visuals"
	var skin_path := folder + "skin.tres"
	var skin: Skin
	for part: MeshInstance3D in skeleton.find_children("*", "MeshInstance3D", true, false):
		var mesh := _save_mesh(part.mesh, material, folder + _part_name(model_name, part.name) + ".res")
		var instance := MeshInstance3D.new()
		instance.name = _part_name(model_name, part.name)
		instance.mesh = mesh
		if part.get_parent() is BoneAttachment3D:
			var attachment := BoneAttachment3D.new()
			attachment.name = (part.get_parent() as BoneAttachment3D).bone_name.capitalize().replace(" ", "")
			attachment.bone_name = (part.get_parent() as BoneAttachment3D).bone_name
			attachment.use_external_skeleton = true
			attachment.external_skeleton = SKELETON
			visuals.add_child(attachment)
			attachment.add_child(instance)
			instance.transform = part.transform
		else:
			if skin == null:
				skin = _skin(part.skin)
				ResourceSaver.save(skin, skin_path)
				skin = load(skin_path)
			instance.skin = skin
			instance.skeleton = SKELETON
			visuals.add_child(instance)
	scene.free()
	for node in visuals.find_children("*", "", true, false):
		node.owner = visuals
	var packed := PackedScene.new()
	packed.pack(visuals)
	visuals.free()
	return ResourceSaver.save(packed, OUTPUT % model_name)


func _part_name(model_name: String, part: String) -> String:
	return part.get_slice("_", part.get_slice_count("_") - 1) if model_name != "knight" else part.trim_prefix("Knight_")


func _save_mesh(source: Mesh, material: Material, path: String) -> Mesh:
	var mesh := source.duplicate() as ArrayMesh
	for surface in mesh.get_surface_count():
		mesh.surface_set_material(surface, material)
	ResourceSaver.save(mesh, path)
	return load(path)


func _skin(source: Skin) -> Skin:
	var skin := source.duplicate() as Skin
	for i in skin.get_bind_count():
		if BIND_RENAMES.has(String(skin.get_bind_name(i))):
			skin.set_bind_name(i, BIND_RENAMES[String(skin.get_bind_name(i))])
	return skin
