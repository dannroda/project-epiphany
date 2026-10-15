extends SceneTree
## Arma la decoración de cada nivel (11.4 overworld) en levels/decor/<nivel>_decor.tscn, que el nivel
## instancia como "Decor". Lee el GridMap, las salas o zonas y lo jugable (los otros hijos del nivel) y reparte, según la
## receta de cada sala o zona, piezas contra las paredes, en las esquinas y en el piso, lejos del paso, de las puertas, de
## los pozos y de lo jugable. Determinístico (semilla por sala): se puede correr de nuevo después de tocar un nivel.
## godot --headless --path . --script res://tools/decorate_levels.gd

const TERRACE_HEIGHT := 2.6
const MESH := "res://assets/epiphany/meshes/%s.res"
const OUT := "res://levels/decor/%s_decor.tscn"
## Plantas que se cortan como el pasto (Breakable): las celdas del kit, las que el terreno orgánico dejó en el piso
## jugable (tools/plantas_overworld.json) y las piezas de la decoración.
const PLANT_CELLS := {
	"Árbol": "res://src/world/plants/arbol.tscn",
	"Queñoa chica": "res://src/world/plants/quenoa_chica.tscn",
	"Cardón": "res://src/world/plants/cardon.tscn",
	"Cardón brazos": "res://src/world/plants/cardon_brazos.tscn",
}
const PLANTS := {
	"ichu_mata": "res://src/world/grass.tscn",
	"flores": "res://src/world/plants/flores.tscn",
	"tola": "res://src/world/plants/tola.tscn",
	"hongos": "res://src/world/plants/hongos.tscn",
	"yareta": "res://src/world/plants/yareta.tscn",
	"cardon_chico": "res://src/world/plants/cardon_chico.tscn",
	"cardon_a": "res://src/world/plants/cardon.tscn",
	"cardon_b": "res://src/world/plants/cardon_brazos.tscn",
	"quenoa_grande": "res://src/world/plants/arbol.tscn",
	"quenoa_chica": "res://src/world/plants/quenoa_chica.tscn",
}
const SCATTERED := "res://tools/plantas_overworld.json"
## Ni plantas ni nada encima de los portales de viaje, con margen para que no asomen sobre el borde.
const PORTAL_SCENE := "res://src/world/travel_portal.tscn"
const PORTAL_CLEAR := 2.0
const CELL := 2.0
## Lo jugable más cerca que esto (m) no deja decorar.
const CLEARANCE := 1.8
const DOOR_CLEARANCE := 2.6
## Más alto que esto, la pieza lleva colisión.
const SOLID_HEIGHT := 0.45
const DIRS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1)]
const NORTH := Vector2i(0, -1)
## Hijos del nivel que no son jugables (no reservan lugar).
const IGNORED := ["GridMap", "WorldEnvironment", "DirectionalLight3D", "NavigationRegion3D", "Camera3D", "Decor"]

## Overworld, por zona: hitos cerca del centro y piezas contra los riscos y los muros, cada una [malla, cuántas];
## props: [malla, nodo del nivel, corrimiento] van pegadas a algo jugable (la cornisa bajo el ojo, el nicho del cofre).
const OVERWORLD := {
	"Zone_start": {"landmarks": ["objetos/fogata", "naturaleza/tronco_caido"], "edge": [["naturaleza/piedra_chica_b", 3], ["naturaleza/ichu_cortado", 4], ["naturaleza/flores", 2]]},
	"Zone_pradera": {"landmarks": ["objetos/apacheta"], "edge": [["naturaleza/piedra_chica_b", 3], ["naturaleza/cardon_chico", 2], ["naturaleza/ichu_cortado", 4], ["naturaleza/yareta", 2], ["naturaleza/flores", 2]]},
	"Zone_arboleda": {"edge": [["naturaleza/tronco_caido", 2], ["naturaleza/cardon_chico", 3], ["naturaleza/roca_grande_b", 1], ["naturaleza/ichu_cortado", 3], ["naturaleza/tocon", 2], ["naturaleza/hongos", 2]]},
	"Zone_risco": {"props": [["lugares/cornisa_ojo", "CliffEye", Vector3(0, 0, 0.3)], ["lugares/nicho_carcaj", "QuiverChest", Vector3(1, 0, 1)], ["lugares/estela_carcaj", "QuiverChest", Vector3(0, 0, -0.75)]], "edge": [["naturaleza/roca_alta", 3], ["naturaleza/piedra_chica_b", 3], ["naturaleza/roca_grande_b", 1], ["naturaleza/yareta", 1]]},
	"Zone_cueva": {"edge": [["lugares/estalagmitas", 4], ["naturaleza/roca_alta", 2], ["lugares/escombro_a", 2]]},
	"Zone_gruta": {"edge": [["lugares/estalagmitas", 5], ["naturaleza/piedra_chica_b", 3]]},
	"Zone_santuario": {"edge": [["objetos/apacheta", 2], ["naturaleza/piedra_chica_b", 3], ["naturaleza/ichu_cortado", 3], ["naturaleza/flores", 1]]},
	"Zone_templo": {"facade": "TempleSeal", "edge": [["lugares/escombro_a", 3], ["naturaleza/piedra_chica_b", 2]]},
}

var _grid: GridMap
var _lib: MeshLibrary
## De dónde salen las colisiones: el kit orgánico del overworld no tiene (12.15), las mismas ids en overworld_kit.tres sí.
var _shapes: MeshLibrary
var _keep_out: Array[Vector3] = []
var _doors: Array[Vector3] = []
var _placed: Array[Vector3] = []
var _portals: Array[Vector3] = []
var _root: Node3D
var _rng := RandomNumberGenerator.new()


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://levels/decor"))
	_decorate("overworld", "area_zone.gd", _overworld_zone)
	quit()


func _decorate(level_name: String, area_script: String, recipe: Callable) -> void:
	var level: Node3D = (load("res://levels/%s.tscn" % level_name) as PackedScene).instantiate()
	_grid = level.get_node("GridMap")
	_lib = _grid.mesh_library
	_shapes = load("res://data/kits/overworld_kit.tres") if _lib.resource_path.ends_with("overworld_organico_kit.tres") else _lib
	_keep_out.clear()
	_doors.clear()
	_placed.clear()
	_portals.clear()
	for node in level.find_children("*", "", true, false):
		if node.scene_file_path == PORTAL_SCENE:
			_portals.append(_origin_in(level, node as Node3D))
	var areas: Array[Area3D] = []
	for child in level.get_children():
		var script: Script = child.get_script()
		if child is Area3D and script and script.resource_path.ends_with(area_script):
			areas.append(child)
		elif child is Node3D and not (child.get_class() in IGNORED or child.name in IGNORED):
			_keep_out.append((child as Node3D).position)
			if "solved_position" in child:
				_keep_out.append(((child as Node3D).position + child.solved_position) / 2.0)
				_keep_out.append(child.solved_position)
			if child.get_class() == "Node3D" and child.get_script() == null and child.scene_file_path.is_empty():
				for inner in child.get_children():
					if inner is Node3D:
						_keep_out.append((child as Node3D).transform * (inner as Node3D).position)
	for cell in _grid.get_used_cells():
		if _name(cell) == "Puerta":
			_doors.append(_center(cell))
	_root = Node3D.new()
	_root.name = "Decor"
	var count := 0
	for area in areas:
		var group := Node3D.new()
		group.name = area.name
		_add(_root, group)
		_rng.seed = hash(level_name + area.name)
		recipe.call(area, _cells_in(area), group)
		count += group.get_child_count()
	if level_name == "overworld":
		_plants()
	var packed := PackedScene.new()
	packed.pack(_root)
	ResourceSaver.save(packed, OUT % level_name)
	print("decorate_levels: %s, %d piezas" % [level_name, count])
	_root.free()
	level.free()


func _plants() -> void:
	var group := Node3D.new()
	group.name = "Plantas"
	_add(_root, group)
	for cell in _grid.get_used_cells():
		if PLANT_CELLS.has(_name(cell)) and not _on_portal(_center(cell)):
			var plant := _scene(PLANT_CELLS[_name(cell)])
			plant.transform = Transform3D(_grid.get_cell_item_basis(cell), _center(cell))
			_add(group, plant)
	for spot: Dictionary in JSON.parse_string(FileAccess.get_file_as_string(SCATTERED)):
		var at := Vector3(spot.at[0], spot.at[1], spot.at[2])
		if _on_portal(at):
			continue
		var plant := _scene(PLANTS[spot.kind])
		plant.position = at
		plant.rotation.y = spot.yaw
		_add(group, plant)


func _origin_in(level: Node3D, node: Node3D) -> Vector3:
	var xform := node.transform
	var parent := node.get_parent() as Node3D
	while parent and parent != level:
		xform = parent.transform * xform
		parent = parent.get_parent() as Node3D
	return xform.origin


func _on_portal(at: Vector3) -> bool:
	return _portals.any(func(p: Vector3) -> bool: return Vector2(p.x - at.x, p.z - at.z).length() < PORTAL_CLEAR)


func _scene(path: String) -> Node3D:
	return (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D


func _overworld_zone(zone: Area3D, cells: Array[Vector3i], group: Node3D) -> void:
	var recipe: Dictionary = OVERWORLD.get(String(zone.name), {})
	var ground := cells.filter(_is_ground)
	var facade: String = recipe.get("facade", "")
	if not facade.is_empty():
		_facade(zone.get_parent().get_node(facade) as Node3D, group)
	for prop: Array in recipe.get("props", []):
		var anchor_node := zone.get_parent().get_node(String(prop[1])) as Node3D
		_mesh(group, prop[0], anchor_node.position + prop[2], anchor_node.rotation.y)
	var center := Vector3(zone.position.x, 0.0, zone.position.z)
	var by_center := ground.duplicate()
	by_center.sort_custom(func(a: Vector3i, b: Vector3i) -> bool: return _center(a).distance_to(center) < _center(b).distance_to(center))
	var anchor := Vector3.INF
	for mesh_name: String in recipe.get("landmarks", []):
		for cell: Vector3i in by_center:
			var at := _center(cell) + _jitter(0.3)
			if _free(at, CLEARANCE + 0.6, 2.2) and (anchor == Vector3.INF or at.distance_to(anchor) < 3.2):
				_mesh(group, mesh_name, at, _rng.randf() * TAU)
				if anchor == Vector3.INF:
					anchor = at
				break
	var edge := ground.filter(func(c: Vector3i) -> bool: return _toward_walls(c) != Vector3.ZERO)
	for entry: Array in recipe.get("edge", []):
		var spots := edge.map(func(c: Vector3i) -> Array: return [_center(c) + _toward_walls(c) * _rng.randf_range(0.3, 0.6) + _jitter(0.25), _rng.randf() * TAU])
		for spot in _pick(spots, entry[1], 2.2, CLEARANCE):
			_mesh(group, entry[0], spot[0], spot[1])


## La fachada del templo detrás del sello de la entrada, con la puerta donde está el sello.
func _facade(seal: Node3D, group: Node3D) -> void:
	var at := seal.position + seal.basis.z * -0.3
	_mesh(group, "lugares/fachada_templo", at, seal.rotation.y, false)
	(group.get_node("FachadaTemplo") as GeometryInstance3D).set_instance_shader_parameter("floor_earth", 0.0)
	var body := StaticBody3D.new()
	body.name = "FachadaTemploMuros"
	body.position = at
	body.rotation.y = seal.rotation.y
	_add(group, body)
	for side in [-1.0, 1.0]:
		var shape := CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		(shape.shape as BoxShape3D).size = Vector3(2.8, 3.0, 1.8)
		shape.position = Vector3(side * 2.6, 1.5, 0.4)
		_add(body, shape)


func _cells_in(area: Area3D) -> Array[Vector3i]:
	var shape := area.get_node("CollisionShape3D") as CollisionShape3D
	var size := (shape.shape as BoxShape3D).size
	var center := area.position + shape.position
	var rect := Rect2(center.x - size.x / 2.0, center.z - size.z / 2.0, size.x, size.z)
	var out: Array[Vector3i] = []
	for cell in _grid.get_used_cells():
		var at := _center(cell)
		if rect.has_point(Vector2(at.x, at.z)):
			out.append(cell)
	return out


## Puntos sobre las caras de pared que dan a esas celdas, mirando hacia adentro: [posición, giro en Y].
func _wall_faces(floors: Array, dirs: Array) -> Array:
	var out := []
	for cell: Vector3i in floors:
		for dir: Vector2i in dirs:
			var wall := cell + Vector3i(dir.x, 0, dir.y)
			if _name(wall).begins_with("Pared"):
				var normal := Vector3(-dir.x, 0, -dir.y)
				out.append([_center(cell) - normal * (CELL / 2.0), atan2(normal.x, normal.z)])
	return out


## Elige hasta count lugares al azar que no estén cerca de lo jugable, de las puertas ni de otra pieza.
func _pick(spots: Array, count: int, spacing: float, clearance: float) -> Array:
	var out := []
	var pool := spots.duplicate()
	while out.size() < count and not pool.is_empty():
		var spot: Array = pool.pop_at(_rng.randi() % pool.size())
		if _free(spot[0], clearance, spacing):
			out.append(spot)
			_placed.append(spot[0])
	return out


func _free(at: Vector3, clearance: float, spacing: float) -> bool:
	for point in _keep_out:
		if Vector2(point.x, point.z).distance_to(Vector2(at.x, at.z)) < clearance:
			return false
	for point in _doors:
		if point.distance_to(at) < DOOR_CLEARANCE:
			return false
	for point in _placed:
		if point.distance_to(at) < spacing:
			return false
	return true


func _mesh(group: Node3D, mesh_name: String, at: Vector3, yaw: float, solid := true) -> void:
	if mesh_name.begins_with("naturaleza/") and PLANTS.has(mesh_name.get_file()):
		var plant := _scene(PLANTS[mesh_name.get_file()])
		plant.position = at
		plant.rotation.y = yaw
		_add(group, plant)
		_placed.append(at)
		return
	var mesh: Mesh = load(MESH % mesh_name)
	var instance := MeshInstance3D.new()
	instance.name = mesh_name.get_file().to_pascal_case()
	instance.mesh = mesh
	var box := mesh.get_aabb()
	if solid and box.size.y > SOLID_HEIGHT:
		var body := StaticBody3D.new()
		body.name = instance.name
		body.position = at
		body.rotation.y = yaw
		_add(group, body)
		instance.name = "Model"
		_add(body, instance)
		var shape := CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		(shape.shape as BoxShape3D).size = Vector3(box.size.x * 0.8, box.size.y, box.size.z * 0.8)
		shape.position = box.get_center()
		_add(body, shape)
	else:
		instance.position = at
		instance.rotation.y = yaw
		_add(group, instance)
	_placed.append(at)


func _add(parent: Node, child: Node) -> void:
	parent.add_child(child, true)
	child.owner = _root
	for inner in child.get_children():
		if inner.owner == null:
			inner.owner = _root


func _name(cell: Vector3i) -> String:
	var item := _grid.get_cell_item(cell)
	return "" if item == GridMap.INVALID_CELL_ITEM else _lib.get_item_name(item)


func _center(cell: Vector3i) -> Vector3:
	return _grid.map_to_local(cell) * Vector3(1, 0, 1) + _grid.position + Vector3(0, cell.y * _grid.cell_size.y, 0)


func _is_floor(cell: Vector3i) -> bool:
	var item_name := _name(cell)
	return item_name.begins_with("Piso")


func _is_ground(cell: Vector3i) -> bool:
	var item_name := _name(cell)
	return item_name == "Piso" or item_name.begins_with("Pasto") or item_name.begins_with("Tierra")


func _is_wall(cell: Vector3i) -> bool:
	var item := _grid.get_cell_item(cell)
	if item == GridMap.INVALID_CELL_ITEM:
		return _rises(cell)
	if _name(cell) in ["Puerta", "Escalón"] or _is_hole(cell):
		return false
	for k in range(0, _shapes.get_item_shapes(item).size(), 2):
		var shapes := _shapes.get_item_shapes(item)
		var box: AABB = (shapes[k + 1] as Transform3D) * (shapes[k] as Shape3D).get_debug_mesh().get_aabb()
		if box.end.y > 0.8:
			return true
	return false


## Terrazas (7.10): en un GridMap de niveles de terraza, una columna con terreno más arriba que la celda es pared (la cara del risco).
func _rises(cell: Vector3i) -> bool:
	if _grid.cell_size.y < TERRACE_HEIGHT:
		return false
	for y in range(cell.y + 1, cell.y + 4):
		if _grid.get_cell_item(Vector3i(cell.x, y, cell.z)) != GridMap.INVALID_CELL_ITEM:
			return true
	return false


## Hacia qué paredes vecinas queda pegada la celda (suma de las direcciones, normalizada; cero si está suelta).
func _toward_walls(cell: Vector3i) -> Vector3:
	var sum := Vector3.ZERO
	for dir in DIRS:
		if _is_wall(cell + Vector3i(dir.x, 0, dir.y)):
			sum += Vector3(dir.x, 0, dir.y)
	return sum.normalized()


func _near_hole(cell: Vector3i) -> bool:
	for dir in DIRS + [Vector2i.ZERO]:
		if _is_hole(cell + Vector3i(dir.x, 0, dir.y)):
			return true
	return false


## Hueco o abismo, con sus variantes por vecinos.
func _is_hole(cell: Vector3i) -> bool:
	var item_name := _name(cell)
	return item_name.begins_with("Hueco") or item_name.begins_with("Abismo")


func _jitter(amount: float) -> Vector3:
	return Vector3(_rng.randf_range(-amount, amount), 0.0, _rng.randf_range(-amount, amount))
