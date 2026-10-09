extends SceneTree
## Arma un "Visuals" por personaje (assets/epiphany/personaje_*.blend, pesados al Rig_Medium de KayKit): mallas en .res
## con el material de la paleta y una escena que se cuelga de un ModelController con su Skeleton3D al lado
## (el rig y las animaciones de siempre).
## godot --headless --path . --script res://tools/build_character_models.gd

const OUTPUT := "res://src/entities/models/%s.tscn"
const MESHES := "res://src/entities/models/meshes/%s/"
const SKELETON := NodePath("../../Skeleton3D")
const MATERIAL := preload("res://data/kits/materials/epiphany.tres")
const CHARACTERS := {
	"jugador": "res://assets/epiphany/personaje_jugador.blend",
	"chullpa": "res://assets/epiphany/personaje_chullpa.blend",
	"chullpa_guardian": "res://assets/epiphany/personaje_chullpa_guardian.blend",
}
## El rig del proyecto no tiene los huesos de las armas; sus binds pasan a la mano (no pesan en ningún vértice).
const BIND_RENAMES := {"handslot.l": "hand.l", "handslot.r": "hand.r"}


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
	var part: MeshInstance3D = skeleton.find_children("*", "MeshInstance3D", true, false)[0]
	var visuals := Node3D.new()
	visuals.name = "Visuals"
	var skin_path := folder + "skin.tres"
	ResourceSaver.save(_skin(part.skin), skin_path)
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = _save_mesh(part.mesh, MATERIAL, folder + "Body.res")
	body.skin = load(skin_path)
	body.skeleton = SKELETON
	visuals.add_child(body)
	scene.free()
	for node in visuals.find_children("*", "", true, false):
		node.owner = visuals
	var packed := PackedScene.new()
	packed.pack(visuals)
	visuals.free()
	return ResourceSaver.save(packed, OUTPUT % model_name)


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
