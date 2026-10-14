extends SceneTree
## Arma el kit de un estilo de mazmorra: los mismos ítems y colisiones que el kit gris, con las piezas de
## assets/epiphany/templo_<estilo>.glb (build_templo.py -- <estilo>) en data/kits/<estilo>_kit.tres.
## godot --headless --path . --script res://tools/build_temple_kit.gd -- chullpa
## Sin estilo arma temple_kit.tres (templo.glb), el kit del templo viejo, que ya no usa ningún nivel.

const SOURCE := "res://data/kits/gray_kit.tres"
const STONE := preload("res://data/kits/materials/epiphany_stone.tres")
const FLOOR := preload("res://data/kits/materials/epiphany.tres")
const HIDDEN_FACES := preload("res://tools/hidden_faces.gd")
## Piezas a las que se les sacan las caras que nunca se ven.
const STRIPPED := ["pared", "pared_nicho", "pared_ojo"]

## id del kit gris → [pieza, material].
const BASE := {
	0: ["piso", FLOOR],
	1: ["pared", STONE],
	2: ["columna", STONE],
	3: ["escalon", STONE],
	4: ["paso_puerta", STONE],
	10: ["hueco", FLOOR],
}
## Variantes (ids desde 11, en este orden): nombre → [id base de donde copia colisión y navmesh, pieza, material].
const VARIANTS := {
	"Piso roto": [0, "piso_roto", FLOOR],
	"Piso grieta": [0, "piso_grieta", FLOOR],
	"Piso musgo": [0, "piso_musgo", FLOOR],
	"Piso arena": [0, "piso_arena", FLOOR],
	"Pared nicho": [1, "pared_nicho", STONE],
	"Pared ojo": [1, "pared_ojo", STONE],
	"Hueco borde": [10, "hueco_borde", FLOOR],
	"Hueco esquina": [10, "hueco_esquina", FLOOR],
	"Hueco pasillo": [10, "hueco_pasillo", FLOOR],
	"Hueco punta": [10, "hueco_punta", FLOOR],
	"Hueco pozo": [10, "hueco_pozo", FLOOR],
}

var _style := _style_name()
var _output := "res://data/kits/%s_kit.tres" % (_style if _style else "temple")
var _source_glb := "res://assets/epiphany/templo%s.glb" % ("_" + _style if _style else "")
var _scene: Node


static func _style_name() -> String:
	var args := OS.get_cmdline_user_args()
	return args[0] if not args.is_empty() else ""


func _initialize() -> void:
	_scene = (load(_source_glb) as PackedScene).instantiate()
	var source: MeshLibrary = load(SOURCE)
	var kit := MeshLibrary.new()
	for id in source.get_item_list():
		kit.create_item(id)
		kit.set_item_name(id, source.get_item_name(id))
		kit.set_item_mesh(id, _piece(BASE[id][0], BASE[id][1]) if BASE.has(id) else source.get_item_mesh(id))
		kit.set_item_shapes(id, source.get_item_shapes(id))
		kit.set_item_navigation_mesh(id, source.get_item_navigation_mesh(id))
	var next := source.get_last_unused_item_id()
	for item_name: String in VARIANTS:
		var variant: Array = VARIANTS[item_name]
		kit.create_item(next)
		kit.set_item_name(next, item_name)
		kit.set_item_mesh(next, _piece(variant[1], variant[2]))
		kit.set_item_shapes(next, source.get_item_shapes(variant[0]))
		kit.set_item_navigation_mesh(next, source.get_item_navigation_mesh(variant[0]))
		next += 1
	_scene.free()
	var uid := ResourceLoader.get_resource_uid(_output) if ResourceLoader.exists(_output) else ResourceUID.INVALID_ID
	var err := ResourceSaver.save(kit, _output)
	if err == OK and uid != ResourceUID.INVALID_ID:
		ResourceSaver.set_uid(_output, uid)
	print(_output.get_file(), ": ", error_string(err), " · ", kit.get_item_list().size(), " ítems")
	quit(0 if err == OK else 1)


func _piece(piece: String, material: Material) -> ArrayMesh:
	var node := _scene.find_child(piece, true, false) as MeshInstance3D
	assert(node != null, "falta la pieza " + piece)
	var mesh: Mesh = HIDDEN_FACES.strip(node.mesh) if piece in STRIPPED else node.mesh
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for surface in mesh.get_surface_count():
		tool.append_from(mesh, surface, Transform3D.IDENTITY)
	tool.set_material(material)
	return tool.commit()
