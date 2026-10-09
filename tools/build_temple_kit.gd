extends SceneTree
## Arma data/kits/temple_kit.tres: los mismos ítems y colisiones que el kit gris, con mallas de KayKit Dungeon Remastered.
## godot --headless --path . --script res://tools/build_temple_kit.gd

const SOURCE := "res://data/kits/gray_kit.tres"
const OUTPUT := "res://data/kits/temple_kit.tres"
const PIECES := "res://assets/kaykit_dungeon_remastered/%s.glb"
const STONE := preload("res://data/kits/materials/kaykit_stone.tres")
const FLOOR := preload("res://data/kits/materials/kaykit_floor.tres")
const WALL_TOP := 2.6
const WALL_BOTTOM := -0.5
const FLOOR_VARIANTS := {
	"Piso rota A": "floor_tile_small_broken_A",
	"Piso rota B": "floor_tile_small_broken_B",
	"Piso yuyos A": "floor_tile_small_weeds_A",
	"Piso yuyos B": "floor_tile_small_weeds_B",
}


func _initialize() -> void:
	var source: MeshLibrary = load(SOURCE)
	var kit := MeshLibrary.new()
	for id in source.get_item_list():
		kit.create_item(id)
		kit.set_item_name(id, source.get_item_name(id))
		kit.set_item_mesh(id, source.get_item_mesh(id))
		kit.set_item_shapes(id, source.get_item_shapes(id))
		kit.set_item_navigation_mesh(id, source.get_item_navigation_mesh(id))
	kit.set_item_mesh(0, _floor("floor_tile_small"))
	kit.set_item_mesh(1, _wall(WALL_BOTTOM, WALL_TOP))
	kit.set_item_mesh(2, _column())
	kit.set_item_mesh(4, _door())
	var next := source.get_last_unused_item_id()
	for item_name: String in FLOOR_VARIANTS:
		kit.create_item(next)
		kit.set_item_name(next, item_name)
		kit.set_item_mesh(next, _floor(FLOOR_VARIANTS[item_name]))
		kit.set_item_shapes(next, source.get_item_shapes(0))
		next += 1
	var err := ResourceSaver.save(kit, OUTPUT)
	print("temple_kit: ", error_string(err), " · ", kit.get_item_list().size(), " ítems")
	quit(0 if err == OK else 1)


func _piece_mesh(piece: String) -> Mesh:
	var scene: Node = (load(PIECES % piece) as PackedScene).instantiate()
	var mesh := (scene.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh
	scene.free()
	return mesh


func _merge(parts: Array, material: Material) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for part: Array in parts:
		var mesh: Mesh = part[0]
		for surface in mesh.get_surface_count():
			tool.append_from(mesh, surface, part[1])
	tool.set_material(material)
	return tool.commit()


## Baldosa de 2 m con la cara de arriba en y = 0.
func _floor(piece: String) -> ArrayMesh:
	return _merge([[_piece_mesh(piece), Transform3D(Basis(), Vector3(0, -0.05, 0))]], FLOOR)


## Celda de pared de 2 × 2 m: medias paredes de KayKit (2 × 4 × 1) en las cuatro caras, estiradas a la altura del kit.
## Las de los costados quedan apenas más bajas y angostas para que no peleen caras coplanares con las del frente.
func _wall(bottom: float, top: float) -> ArrayMesh:
	var half := _piece_mesh("wall_half")
	var height := (top - bottom) / 4.0
	var parts := []
	for side in [1.0, -1.0]:
		var basis := Basis(Vector3.UP, 0.0 if side > 0.0 else PI) * Basis.from_scale(Vector3(0.995, height, 1.0))
		parts.append([half, Transform3D(basis, Vector3(-side, bottom, side * 0.5))])
		var turned := Basis(Vector3.UP, PI / 2.0 if side > 0.0 else -PI / 2.0) * Basis.from_scale(Vector3(0.995, height * 0.997, 1.0))
		parts.append([half, Transform3D(turned, Vector3(side * 0.5, bottom, side))])
	return _merge(parts, STONE)


func _column() -> ArrayMesh:
	var basis := Basis.from_scale(Vector3(0.667, WALL_TOP / 4.0, 0.667))
	return _merge([[_piece_mesh("pillar"), Transform3D(basis, Vector3.ZERO)]], STONE)


## Paso de puerta: baldosa abajo y un dintel de pared arriba.
func _door() -> ArrayMesh:
	var floor_tile := _floor("floor_tile_small")
	var lintel := _wall(2.4, WALL_TOP)
	var tool := SurfaceTool.new()
	var mesh := ArrayMesh.new()
	tool.create_from(floor_tile, 0)
	tool.set_material(FLOOR)
	tool.commit(mesh)
	tool.create_from(lintel, 0)
	tool.set_material(STONE)
	tool.commit(mesh)
	return mesh
