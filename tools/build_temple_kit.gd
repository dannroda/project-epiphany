extends SceneTree
## Arma data/kits/temple_kit.tres: los mismos ítems y colisiones que el kit gris, con las piezas de assets/epiphany/templo.blend.
## godot --headless --path . --script res://tools/build_temple_kit.gd

const SOURCE := "res://data/kits/gray_kit.tres"
const OUTPUT := "res://data/kits/temple_kit.tres"
const BLEND := "res://assets/epiphany/templo.blend"
const STONE := preload("res://data/kits/materials/epiphany_stone.tres")
const FLOOR := preload("res://data/kits/materials/epiphany.tres")

## id del kit gris → [pieza, material].
const BASE := {
	0: ["piso", FLOOR],
	1: ["pared", STONE],
	2: ["columna", STONE],
	3: ["escalon", STONE],
	4: ["paso_puerta", STONE],
}
## Variantes (ids desde 11, en este orden): nombre → [id base de donde copia colisión y navmesh, pieza, material].
const VARIANTS := {
	"Piso roto": [0, "piso_roto", FLOOR],
	"Piso grieta": [0, "piso_grieta", FLOOR],
	"Piso musgo": [0, "piso_musgo", FLOOR],
	"Piso arena": [0, "piso_arena", FLOOR],
	"Pared nicho": [1, "pared_nicho", STONE],
	"Pared ojo": [1, "pared_ojo", STONE],
}

var _scene: Node


func _initialize() -> void:
	_scene = (load(BLEND) as PackedScene).instantiate()
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
	var err := ResourceSaver.save(kit, OUTPUT)
	print("temple_kit: ", error_string(err), " · ", kit.get_item_list().size(), " ítems")
	quit(0 if err == OK else 1)


func _piece(piece: String, material: Material) -> ArrayMesh:
	var node := _scene.find_child(piece, true, false) as MeshInstance3D
	assert(node != null, "falta la pieza " + piece)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for surface in node.mesh.get_surface_count():
		tool.append_from(node.mesh, surface, Transform3D.IDENTITY)
	tool.set_material(material)
	return tool.commit()
