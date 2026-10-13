extends SceneTree
## Arma data/kits/overworld_kit.tres: los ítems y colisiones del kit gris con las piezas propias de assets/epiphany,
## más variantes (ids desde 11) que reparte tools/vary_overworld.gd.
## También arma data/kits/overworld_organico_kit.tres para el overworld de terreno orgánico (12.15): los mismos ítems, pero
## el terreno (TERRAIN) queda sin malla ni colisión, porque lo dibuja assets/epiphany/terreno_organico.glb, y las piezas que
## quedan pierden su piso.
## godot --headless --path . --script res://tools/build_overworld_kit.gd

const SOURCE := "res://data/kits/gray_kit.tres"
const OUTPUT := "res://data/kits/overworld_kit.tres"
const ORGANIC_OUTPUT := "res://data/kits/overworld_organico_kit.tres"
const TERRAIN := ["Piso", "Pasto", "Tierra", "Lajas", "Pared", "Acantilado", "Andén", "Risco", "Abismo", "Hueco", "Monte", "Cueva", "Escalón"]
## Más bajo que esto (m) es piso de la celda.
const FLOOR_TOP := 0.01
## Celdas de plantas que se cortan: en el kit orgánico quedan sin malla ni colisión, decorate_levels.gd pone la escena.
const PLANTS := ["Árbol", "Queñoa chica", "Cardón", "Cardón brazos"]
const GLB := "res://assets/epiphany/%s.glb"
const MATERIAL := preload("res://data/kits/materials/epiphany_outdoor.tres")
## Las paredes que pueden tapar al player: se recortan alrededor de él.
const WALL_MATERIAL := preload("res://data/kits/materials/epiphany_wall.tres")
const WALL_IDS := [1, 6]
## Abismo y pozo no tienen piso: el que cae ahí cae (un Pit abajo lo devuelve).
const HOLE_IDS := [9, 10]
## Las celdas con alguna de estas piezas usan el material con viento.
const WIND_MATERIAL := preload("res://data/kits/materials/epiphany_wind.tres")
const WALL_WIND_MATERIAL := preload("res://data/kits/materials/epiphany_wall_wind.tres")
const WINDY := ["pasto_flores", "pasto_ichu", "monte_ichu", "monte_flores", "risco_ichu", "risco_flores", "tierra_pasto", "tola", "quenoa_grande", "quenoa_chica"]
## Piso que llevan esas paredes adentro: por el agujero se ve suelo y no el vacío.
const WALL_FLOOR := "terreno_overworld/tierra"
const HIDDEN_FACES := preload("res://tools/hidden_faces.gd")
## Piezas a las que se les sacan las caras que nunca se ven.
const STRIPPED := ["terreno_overworld/anden", "terreno_overworld/risco", "terreno_overworld/tierra"]

## id del kit gris → piezas que se funden en la celda ("kit/pieza").
const BASE := {
	0: ["terreno_overworld/tierra"],
	1: ["terreno_overworld/risco"],
	2: ["terreno_overworld/pasto", "lugares/monolito"],
	3: ["terreno_overworld/escalon"],
	5: ["terreno_overworld/pasto"],
	6: ["terreno_overworld/anden"],
	7: ["terreno_overworld/pirca"],
	8: ["terreno_overworld/pasto", "naturaleza/quenoa_grande"],
	9: ["terreno_overworld/abismo"],
	10: ["terreno_overworld/abismo"],
}
## Variantes: nombre → [id base de donde copia colisión y navmesh, piezas ("pieza@y" la sube y metros)]. Las "borde" son paredes sin agujero, para
## el borde del mundo (OverworldMap las pone donde del lado de la cámara no hay nada).
const VARIANTS := {
	"Pasto flores": [5, ["terreno_overworld/pasto_flores"]],
	"Pasto piedras": [5, ["terreno_overworld/pasto_piedras"]],
	"Pasto ichu": [5, ["terreno_overworld/pasto_ichu"]],
	"Pasto tola": [5, ["terreno_overworld/pasto", "naturaleza/tola"]],
	"Tierra borde": [5, ["terreno_overworld/tierra_borde"]],
	"Tierra esquina": [5, ["terreno_overworld/tierra_esquina"]],
	"Tierra esquina int": [5, ["terreno_overworld/tierra_esquina_int"]],
	"Tierra piedras": [0, ["terreno_overworld/tierra_piedras"]],
	"Lajas": [0, ["terreno_overworld/lajas"]],
	"Lajas rotas": [0, ["terreno_overworld/lajas_rotas"]],
	"Lajas pasto": [0, ["terreno_overworld/lajas_pasto"]],
	"Risco": [6, ["terreno_overworld/risco"]],
	"Pirca rota": [7, ["terreno_overworld/pirca_rota"]],
	"Pirca esquina": [7, ["terreno_overworld/pirca_esquina"]],
	"Pirca final": [7, ["terreno_overworld/pirca_final"]],
	"Queñoa chica": [8, ["terreno_overworld/pasto", "naturaleza/quenoa_chica"]],
	"Cardón": [8, ["terreno_overworld/pasto", "naturaleza/cardon_a"]],
	"Cardón brazos": [8, ["terreno_overworld/pasto", "naturaleza/cardon_b"]],
	"Roca grande": [8, ["terreno_overworld/pasto", "naturaleza/roca_grande_a"]],
	"Pared borde": [1, ["terreno_overworld/risco"]],
	"Andén borde": [6, ["terreno_overworld/anden"]],
	"Risco borde": [6, ["terreno_overworld/risco"]],
	"Cueva piso": [0, ["lugares/cueva_piso"]],
	"Cueva pared": [6, ["lugares/cueva_pared"]],
	"Abismo borde": [9, ["terreno_overworld/abismo_borde"]],
	"Abismo esquina": [9, ["terreno_overworld/abismo_esquina"]],
	"Abismo pasillo": [9, ["terreno_overworld/abismo_pasillo"]],
	"Abismo punta": [9, ["terreno_overworld/abismo_punta"]],
	"Abismo pozo": [9, ["terreno_overworld/abismo_pozo"]],
	"Pirca poste": [7, ["terreno_overworld/pirca_poste"]],
	"Monte": [10, ["terreno_overworld/monte"]],
	"Monte ichu": [10, ["terreno_overworld/monte_ichu"]],
	"Monte piedras": [10, ["terreno_overworld/monte_piedras"]],
	"Monte flores": [10, ["terreno_overworld/monte_flores"]],
	"Monte queñoa": [10, ["terreno_overworld/monte", "naturaleza/quenoa_grande@2.6"]],
	"Monte queñoa chica": [10, ["terreno_overworld/monte_ichu", "naturaleza/quenoa_chica@2.6"]],
	"Monte cardón": [10, ["terreno_overworld/monte", "naturaleza/cardon_a@2.6"]],
	"Risco ichu": [6, ["terreno_overworld/risco_ichu"]],
	"Risco ichu borde": [6, ["terreno_overworld/risco_ichu"]],
	"Risco flores": [6, ["terreno_overworld/risco_flores"]],
	"Risco flores borde": [6, ["terreno_overworld/risco_flores"]],
	"Tierra manchas": [0, ["terreno_overworld/tierra_manchas"]],
	"Tierra guijarros": [0, ["terreno_overworld/tierra_guijarros"]],
	"Tierra huellas": [0, ["terreno_overworld/tierra_huellas"]],
	"Tierra pasto": [0, ["terreno_overworld/tierra_pasto"]],
}

## Las celdas de abismo llevan capas de niebla (alturas en m) como segunda superficie.
const MIST_MATERIAL := preload("res://data/kits/materials/abyss_mist.tres")
const MIST_LAYERS := [-0.9, -1.8]

var _scenes := {}


func _initialize() -> void:
	var source: MeshLibrary = load(SOURCE)
	var kit := MeshLibrary.new()
	for id in source.get_item_list():
		kit.create_item(id)
		kit.set_item_name(id, source.get_item_name(id))
		kit.set_item_mesh(id, _merge(BASE[id], id in WALL_IDS) if BASE.has(id) else source.get_item_mesh(id))
		kit.set_item_shapes(id, [] if id in HOLE_IDS else source.get_item_shapes(id))
		kit.set_item_navigation_mesh(id, source.get_item_navigation_mesh(id))
	var next := source.get_last_unused_item_id()
	for item_name: String in VARIANTS:
		var base: int = VARIANTS[item_name][0]
		kit.create_item(next)
		kit.set_item_name(next, item_name)
		kit.set_item_mesh(next, _merge(VARIANTS[item_name][1], base in WALL_IDS and not item_name.ends_with(" borde")))
		kit.set_item_shapes(next, [] if base in HOLE_IDS else source.get_item_shapes(base))
		kit.set_item_navigation_mesh(next, source.get_item_navigation_mesh(base))
		next += 1
	for scene: Node in _scenes.values():
		scene.free()
	var err := _save(kit, OUTPUT)
	print("overworld_kit: ", error_string(err), " · ", kit.get_item_list().size(), " ítems")
	var organic_err := _save(_organic(kit), ORGANIC_OUTPUT)
	print("overworld_organico_kit: ", error_string(organic_err))
	quit(0 if err == OK and organic_err == OK else 1)


func _save(kit: MeshLibrary, path: String) -> Error:
	var uid := ResourceLoader.get_resource_uid(path)
	var err := ResourceSaver.save(kit, path)
	if err == OK and uid != ResourceUID.INVALID_ID:
		ResourceSaver.set_uid(path, uid)
	return err


func _organic(kit: MeshLibrary) -> MeshLibrary:
	var organic := MeshLibrary.new()
	for id in kit.get_item_list():
		var item_name := kit.get_item_name(id)
		organic.create_item(id)
		organic.set_item_name(id, item_name)
		if item_name in PLANTS or TERRAIN.any(func(prefix: String) -> bool: return item_name.begins_with(prefix)):
			organic.set_item_mesh(id, ArrayMesh.new())
			continue
		organic.set_item_mesh(id, _without_floor(kit.get_item_mesh(id)))
		var shapes := kit.get_item_shapes(id)
		var kept := []
		for i in range(0, shapes.size(), 2):
			var top: float = (shapes[i + 1] as Transform3D).origin.y + (shapes[i] as BoxShape3D).size.y / 2.0 if shapes[i] is BoxShape3D else 1.0
			if top > FLOOR_TOP:
				kept += [shapes[i], shapes[i + 1]]
		organic.set_item_shapes(id, kept)
	return organic


func _without_floor(mesh: Mesh) -> ArrayMesh:
	var result := ArrayMesh.new()
	for surface in mesh.get_surface_count():
		var tool := SurfaceTool.new()
		tool.create_from(mesh, surface)
		var arrays := tool.commit_to_arrays()
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var kept := PackedInt32Array()
		for i in range(0, indices.size(), 3):
			if maxf(vertices[indices[i]].y, maxf(vertices[indices[i + 1]].y, vertices[indices[i + 2]].y)) > FLOOR_TOP:
				kept.append_array([indices[i], indices[i + 1], indices[i + 2]])
		if kept.is_empty():
			continue
		arrays[Mesh.ARRAY_INDEX] = kept
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		result.surface_set_material(result.get_surface_count() - 1, mesh.surface_get_material(surface))
	return result


func _piece(path: String) -> Mesh:
	var parts := path.split("/")
	if not _scenes.has(parts[0]):
		_scenes[parts[0]] = (load(GLB % parts[0]) as PackedScene).instantiate()
	var node := (_scenes[parts[0]] as Node).find_child(parts[1], true, false) as MeshInstance3D
	assert(node != null, "falta la pieza " + path)
	return HIDDEN_FACES.strip(node.mesh) if path in STRIPPED else node.mesh


func _merge(pieces: Array, wall := false) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for path: String in pieces + ([WALL_FLOOR] if wall else []):
		var mesh := _piece(path.get_slice("@", 0))
		var lift := Transform3D(Basis.IDENTITY, Vector3.UP * float(path.get_slice("@", 1))) if "@" in path else Transform3D.IDENTITY
		for surface in mesh.get_surface_count():
			tool.append_from(mesh, surface, lift)
	var windy := pieces.any(func(path: String) -> bool: return path.get_slice("@", 0).get_file() in WINDY)
	if wall:
		tool.set_material(WALL_WIND_MATERIAL if windy else WALL_MATERIAL)
	else:
		tool.set_material(WIND_MATERIAL if windy else MATERIAL)
	var mesh := tool.commit()
	if pieces.any(func(path: String) -> bool: return path.begins_with("terreno_overworld/abismo")):
		_add_mist(mesh)
	return mesh


func _add_mist(mesh: ArrayMesh) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_normal(Vector3.UP)
	for y: float in MIST_LAYERS:
		var corners := [Vector3(-1, y, -1), Vector3(1, y, -1), Vector3(1, y, 1), Vector3(-1, y, 1)]
		for i: int in [0, 1, 2, 0, 2, 3]:
			tool.add_vertex(corners[i])
	tool.set_material(MIST_MATERIAL)
	tool.commit(mesh)
