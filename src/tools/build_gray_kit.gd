# godot --headless --path . --script res://src/tools/build_gray_kit.gd
extends SceneTree
## Arma el kit de bloques grises (MeshLibrary para GridMap) con las texturas de prototipo de Kenney.
## Celdas de 2 m; el piso queda en y = 0 y las paredes miden WALL_HEIGHT (lo mismo que `TopDownCamera.wall_height`).
## El abismo no se ve como pared: su colisión llega a 0.6 m, así que frena al player pero las flechas pasan por arriba.

const OUT := "res://data/kits/gray_kit.tres"
const MATERIALS := "res://data/kits/materials/"
const TEXTURES := "res://assets/Prototype Textures/PNG/"
const CELL := 2.0
const WALL_HEIGHT := 2.6
const FLOOR_DEPTH := 0.5
const DOOR_HEIGHT := 2.4

enum Item { FLOOR, WALL, COLUMN, STEP, DOORWAY, GRASS, CLIFF, FENCE, TREE, ABYSS }


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MATERIALS))
	var floor_material := _material("floor", "Dark/texture_03.png")
	var wall_material := _material("wall", "Light/texture_02.png", Color(0.5, 0.5, 0.55))
	var column_material := _material("column", "Orange/texture_04.png")
	var step_material := _material("step", "Dark/texture_08.png", Color(1.3, 1.3, 1.3))
	var floor_box := _box(Vector3(CELL, FLOOR_DEPTH, CELL), -FLOOR_DEPTH / 2.0)
	var library := MeshLibrary.new()
	_add(library, Item.FLOOR, "Piso", [[floor_box, floor_material]], [floor_box])
	var wall_box := _box(Vector3(CELL, WALL_HEIGHT + FLOOR_DEPTH, CELL), (WALL_HEIGHT - FLOOR_DEPTH) / 2.0)
	_add(library, Item.WALL, "Pared", [[wall_box, wall_material]], [wall_box])
	var column_box := _box(Vector3(1.0, WALL_HEIGHT, 1.0), WALL_HEIGHT / 2.0)
	_add(library, Item.COLUMN, "Columna", [[floor_box, floor_material], [column_box, column_material]], [floor_box, column_box])
	var step_box := _box(Vector3(CELL, FLOOR_DEPTH + 0.6, CELL), (0.6 - FLOOR_DEPTH) / 2.0)
	_add(library, Item.STEP, "Escalón", [[step_box, step_material]], [step_box])
	var lintel := _box(Vector3(CELL, WALL_HEIGHT - DOOR_HEIGHT, CELL), (WALL_HEIGHT + DOOR_HEIGHT) / 2.0)
	_add(library, Item.DOORWAY, "Puerta", [[floor_box, floor_material], [lintel, wall_material]], [floor_box])
	var grass_material := _material("grass", "Light/texture_02.png", Color(0.48, 0.66, 0.42))
	var cliff_material := _material("cliff", "Light/texture_04.png", Color(0.58, 0.48, 0.38))
	var fence_material := _material("fence", "Light/texture_01.png", Color(0.55, 0.38, 0.24))
	var tree_material := _material("tree", "Light/texture_01.png", Color(0.24, 0.42, 0.27))
	var abyss_material := _material("abyss", "Dark/texture_01.png", Color(0.12, 0.12, 0.16))
	_add(library, Item.GRASS, "Pasto", [[floor_box, grass_material]], [floor_box])
	_add(library, Item.CLIFF, "Acantilado", [[wall_box, cliff_material]], [wall_box])
	var fence_box := _box(Vector3(CELL, 0.9, 0.3), 0.45)
	_add(library, Item.FENCE, "Cerco", [[floor_box, grass_material], [fence_box, fence_material]], [floor_box, fence_box])
	var tree_box := _box(Vector3(1.6, WALL_HEIGHT, 1.6), WALL_HEIGHT / 2.0)
	_add(library, Item.TREE, "Árbol", [[floor_box, grass_material], [tree_box, tree_material]], [floor_box, tree_box])
	var abyss_floor := _box(Vector3(CELL + 2.0, FLOOR_DEPTH, CELL + 2.0), -1.6)
	var abyss_block := _box(Vector3(CELL, 4.6, CELL), -1.7)
	_add(library, Item.ABYSS, "Abismo", [[abyss_floor, abyss_material]], [abyss_block])
	print(ResourceSaver.save(library, OUT))
	quit()


func _material(file: String, texture: String, tint := Color.WHITE) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = load(TEXTURES + texture)
	material.albedo_color = tint
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE / CELL
	material.uv1_offset = Vector3.ONE * 0.5
	var path := MATERIALS + file + ".tres"
	ResourceSaver.save(material, path)
	return load(path)


## [tamaño, centro en y]
func _box(size: Vector3, center_y: float) -> Array:
	return [size, center_y]


func _add(library: MeshLibrary, id: int, item_name: String, parts: Array, colliders: Array) -> void:
	var mesh := ArrayMesh.new()
	for part: Array in parts:
		var box: Array = part[0]
		var source := BoxMesh.new()
		source.size = box[0]
		var arrays := source.get_mesh_arrays()
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in vertices.size():
			vertices[i].y += box[1]
		arrays[Mesh.ARRAY_VERTEX] = vertices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, part[1])
	library.create_item(id)
	library.set_item_name(id, item_name)
	library.set_item_mesh(id, mesh)
	var shapes := []
	for box: Array in colliders:
		var shape := BoxShape3D.new()
		shape.size = box[0]
		shapes.append(shape)
		shapes.append(Transform3D(Basis.IDENTITY, Vector3(0, box[1], 0)))
	library.set_item_shapes(id, shapes)
