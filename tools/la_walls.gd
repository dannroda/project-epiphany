extends SceneTree
## Prueba de paredes inclinadas a lo Link's Awakening sobre la Chullpa: cada celda de pared baja en rampa hacia los vecinos con piso.
## export: tools/paredes_la.json con las formas que usa el nivel (luego blender -b -P tools/blender/build_paredes_la.py).
## build: data/kits/chullpa_la_kit.tres (kit chullpa + piezas de paredes_la.glb) y debug/la/chullpa_la.tscn.
## Las celdas Puerta llevan un corte (paso) o, si tienen escalera, un corte ciego con escalones (sube, baja).
## godot --headless --path . --script res://tools/la_walls.gd -- export|build

const LEVEL := "res://levels/chullpa.tscn"
const KIT := "res://data/kits/chullpa_kit.tres"
const OUT_KIT := "res://data/kits/chullpa_la_kit.tres"
const OUT_LEVEL := "res://debug/la/chullpa_la.tscn"
const SHAPES := "res://tools/paredes_la.json"
const MESHES := "res://assets/epiphany/meshes/paredes_la/%s_la_%s.res"
const STONE := preload("res://data/kits/materials/epiphany_stone.tres")
const BRAZIER := preload("res://assets/epiphany/meshes/templo_chullpa/brasero.res")
const WALLS := ["Pared", "Pared nicho", "Pared ojo"]
const DOOR := "Puerta"
## kind de la pieza → [nombre del ítem, ítem del kit de donde copia colisión y navmesh].
const KINDS := {"pared": ["Pared LA ", "Pared"], "paso": ["Paso LA ", "Puerta"], "sube": ["Sube LA ", "Piso"], "baja": ["Baja LA ", "Piso"]}
const SIDES := {"n": Vector3i(0, 0, -1), "e": Vector3i(1, 0, 0), "s": Vector3i(0, 0, 1), "o": Vector3i(-1, 0, 0)}
const CORNERS := ["ne", "se", "so", "no"]
## Rampa por lado con piso y alto de las paredes (como en build_paredes_la.py); la cámara tapa más allá de MASK_MARGIN.
const WALL_RUN := {"n": 1.4, "s": 0.5, "e": 0.5, "o": 0.5}
const WALL_HEIGHT := 3.0
## Alto de los pilares (PILLAR en build_paredes_la.py): hasta ahí tapa la cámara.
const PILLAR_HEIGHT := 3.6
## Para encuadrar, la cámara mira el tope de la pared norte en el borde del piso: con esto llega a ver también la cresta.
const FRAME_HEIGHT := 5.4
const MASK_MARGIN := 2.0
## Velo que oscurece la parte de afuera de las paredes hasta el negro de la máscara: arranca a esta distancia del piso.
const FADE_START := {"n": 0.9, "s": 0.4, "e": 0.3, "o": 0.3}
## Y llega al negro a esta distancia (abajo la cresta se ve poco: la máscara la tapa antes).
const FADE_END := {"n": 1.8, "s": 1.8, "e": 1.8, "o": 1.8}
const FADE := preload("res://debug/la/borde_oscuro.gdshader")
const FOCUS := preload("res://debug/la/enfoque_la.gd")
const VIGNETTE := preload("res://debug/la/vineta_la.gdshader")
const BIG_POT := "res://src/world/big_pot.tscn"
## Vasijas que pasan a ser las grandes que se empujan (big_pot.tscn).
const BIG_POTS := ["OsarioPot1", "OsarioPot2"]
## Curva de tono de LA (visor de LA): por debajo de TOE_PIVOT (lineal) oscurece con esta potencia, arriba queda igual.
const TOE_PIVOT := 0.28
const TOE_POWER := 2.23
## Luz de relleno fría, como el ambiente de las salas de LA.
const AMBIENT_COLOR := Color(0.62, 0.72, 0.85)
const AMBIENT_ENERGY := 1.7
const GLOSS_ROUGHNESS := 0.5
const GLOSS_SPECULAR := 0.4
const EXPOSURE := 1.0
const VIGNETTE_STRENGTH := 0.7
const BRAZIER_SCALE := 0.55
## Colgados de la cara de la pared, como en LA: a este alto y esto por delante de la roca.
const BRAZIER_HEIGHT := 1.9
const BRAZIER_SETBACK := 0.25
const BRAZIER_FLAME := 1.07
## Fuego de las antorchas como en el visor de LA: una luz chica y fuerte pegada a la llama.
const FIRE_OFFSET := Vector3(0, 0.3, 0.3)
const FIRE_ENERGY := 3.5
const FIRE_RANGE := 4.0
const DOOR_LEAF_SCALE := Vector3(0.7, 0.8, 1.0)
## Cámara con perspectiva como LA: la sala se ve en trapecio (abajo más ancha) y asoman las caras de los costados.
## La cámara de LA, calibrada en el visor de LA contra capturas: 65° sobre el horizonte, 28° de campo, a 23 m. La sala
## es más grande que la pantalla y la cámara se mueve adentro.
const CAMERA_PITCH := 65.0
const CAMERA_DISTANCE := 34.0
const FIELD_OF_VIEW := 28.0
## Desenfoque arriba y abajo de la pantalla, solo fuera del piso: el borde sur (con Kai parado) queda a ~5.5 m más cerca y
## la cresta norte a ~2 m más lejos.
const FOCUS_NEAR := 3.5
const FOCUS_FAR := 2.5
## Un foco por sala que baja desde arriba, un poco desde el sur para que dé en la pared norte.
const ROOM_LIGHT_HEIGHT := 7.0
const ROOM_LIGHT_SOUTH := 1.5
const ROOM_LIGHT_TILT := 13.0
const ROOM_LIGHT_COLOR := Color(1.0, 0.9, 0.78)
const ROOM_LIGHT_ENERGY := 2.2
const ROOM_LIGHT_ANGLE := 75.0
## Menos de 1: el borde del foco se esfuma de a poco en vez de cortar.
const ROOM_LIGHT_SOFTNESS := 0.5
## En lugar del sol, la luz fría de LA que llega del lado de la cámara (el sur, en alto) y aclara las caras de las paredes.
const SUN_ENERGY := 0.7
const SUN_COLOR := Color(0.62, 0.78, 1.0)
const SUN_ELEVATION := 40.0
## Las vasijas, del ancho de la placa del botón (1.4 m, como en LA, que pueden reemplazar a un bloque sobre él) y algo
## más bajas para no pasar a Kai. Solo el modelo.
const POT_SCALE := Vector3(2.1, 1.5, 2.1)


func _initialize() -> void:
	var mode := OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "export"
	var level: Node = (load(LEVEL) as PackedScene).instantiate()
	_spread(level)
	var cells := {}
	for grid: GridMap in level.find_children("*", "GridMap", true, false):
		cells[grid] = _shapes(grid)
	if mode == "export":
		var codes := {}
		for kind: String in KINDS:
			codes[kind] = {}
		for grid: GridMap in cells:
			for shape: Array in cells[grid].values():
				codes[shape[0]][shape[1]] = true
		var out := {}
		for kind: String in codes:
			out[kind] = codes[kind].keys()
			out[kind].sort()
		FileAccess.open(SHAPES, FileAccess.WRITE).store_string(JSON.stringify(out, "\t") + "\n")
		print(SHAPES, ": ", out)
	else:
		var kit := _kit()
		for grid: GridMap in cells:
			grid.mesh_library = kit
			for cell: Vector3i in cells[grid]:
				var shape: Array = cells[grid][cell]
				grid.set_cell_item(cell, kit.find_item_by_name(KINDS[shape[0]][0] + shape[1]))
		_dress(level)
		var packed := PackedScene.new()
		packed.pack(level)
		print(OUT_LEVEL, ": ", error_string(ResourceSaver.save(packed, OUT_LEVEL)))
	level.free()
	quit()


## Antorchas a braseros sobre el borde, puertas a la medida del corte, sin los escalones viejos y la cámara casi sin perspectiva.
func _dress(level: Node) -> void:
	_vignette(level)
	for pot: Node in level.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n.name in BIG_POTS):
		_big_pot(level, pot as Node3D)
	for node: Node in level.find_children("*", "", true, false):
		var path := node.scene_file_path
		if path.ends_with("wall_torch.tscn"):
			var torch := node as Node3D
			var facing := torch.transform.basis.z.normalized()
			var side := "s" if facing.z > 0.5 else "n" if facing.z < -0.5 else "e" if facing.x > 0.5 else "o"
			torch.position = torch.position - facing * (WALL_RUN[side] * BRAZIER_HEIGHT / WALL_HEIGHT - BRAZIER_SETBACK)
			torch.position.y = BRAZIER_HEIGHT
			var model := torch.get_node("Model") as MeshInstance3D
			model.mesh = BRAZIER
			model.position = Vector3.ZERO
			model.scale = Vector3.ONE * BRAZIER_SCALE
			for part: String in ["Flame", "Light"]:
				torch.get_node(part).position = Vector3(0, BRAZIER_FLAME * BRAZIER_SCALE, 0)
			var fire := torch.get_node("Light") as OmniLight3D
			fire.position += FIRE_OFFSET
			fire.light_energy = FIRE_ENERGY
			fire.omni_range = FIRE_RANGE
			fire.omni_attenuation = 1.0
			(torch.get_node("Glow") as Node3D).visible = false
			level.set_editable_instance(torch, true)
		elif path.ends_with("door.tscn"):
			node.set("depth", 0.0)
			for leaf: String in ["Leaf/LeafMesh", "Leaf/LeafBack"]:
				(node.get_node(leaf) as Node3D).scale = DOOR_LEAF_SCALE
			level.set_editable_instance(node, true)
		elif _stairs_kind(node) != "":
			(node.get_node("Visual") as Node3D).visible = false
			level.set_editable_instance(node, true)
		elif node is Area3D and "map_cell" in node:
			_fade(level, node as Area3D)
			_light(level, node as Area3D)
		elif node is WorldEnvironment:
			var env := (node as WorldEnvironment).environment.duplicate() as Environment
			env.background_color = Color.BLACK
			env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			env.ambient_light_color = AMBIENT_COLOR
			env.ambient_light_energy = AMBIENT_ENERGY
			env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
			env.tonemap_exposure = EXPOSURE
			env.reflected_light_source = Environment.REFLECTION_SOURCE_BG
			env.adjustment_enabled = true
			env.adjustment_saturation = 0.8
			env.adjustment_color_correction = _tone_curve()
			env.glow_enabled = true
			env.glow_intensity = 0.8
			env.glow_bloom = 0.0
			env.glow_hdr_threshold = 1.2
			env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
			env.ssao_enabled = true
			env.ssao_radius = 0.8
			env.ssao_intensity = 1.5
			(node as WorldEnvironment).environment = env
		elif node is DirectionalLight3D:
			var sun := node as DirectionalLight3D
			sun.light_energy = SUN_ENERGY
			sun.light_color = SUN_COLOR
			sun.rotation = Vector3(deg_to_rad(-SUN_ELEVATION), 0, 0)
			sun.shadow_enabled = false
		elif node is Camera3D and "cuts_south_wall" in node:
			var pitch := deg_to_rad(CAMERA_PITCH)
			node.set("offset", Vector3(0, sin(pitch), cos(pitch)) * CAMERA_DISTANCE)
			var blur := CameraAttributesPractical.new()
			blur.dof_blur_far_enabled = true
			blur.dof_blur_far_distance = CAMERA_DISTANCE + FOCUS_FAR
			blur.dof_blur_far_transition = 6.0
			blur.dof_blur_near_enabled = true
			blur.dof_blur_near_distance = CAMERA_DISTANCE - FOCUS_NEAR
			blur.dof_blur_near_transition = 3.0
			blur.dof_blur_amount = 0.12
			(node as Camera3D).attributes = blur
			var focus := Node.new()
			focus.name = "EnfoqueLA"
			focus.set_script(FOCUS)
			focus.set("near_margin", FOCUS_NEAR)
			focus.set("far_margin", FOCUS_FAR)
			node.add_child(focus)
			focus.owner = level
			node.set("orthographic", false)
			node.set("field_of_view", FIELD_OF_VIEW)
			node.set("cuts_south_wall", true)
			node.set("south_wall_cut", PILLAR_HEIGHT)
			node.set("south_wall_reach", MASK_MARGIN - 0.3)
			node.set("wall_height", FRAME_HEIGHT)
			node.set("mask_margin", MASK_MARGIN)
		if path.get_file() == "pot.tscn":
			(node.get_node("Body/Model") as Node3D).scale = POT_SCALE
			level.set_editable_instance(node, true)


## Como en LA, la piedra y el piso brillan un poco y reflejan la sala (sondas de reflejo por sala).
var _glossy_cache := {}


func _glossy(material: Material) -> Material:
	if not material is ShaderMaterial or not "cutaway" in (material as ShaderMaterial).shader.resource_path:
		return material
	if not _glossy_cache.has(material):
		var copy := material.duplicate() as ShaderMaterial
		copy.set_shader_parameter("roughness", GLOSS_ROUGHNESS)
		copy.set_shader_parameter("specular", GLOSS_SPECULAR)
		_glossy_cache[material] = copy
	return _glossy_cache[material]


func _tone_curve() -> GradientTexture1D:
	const N := 33
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for i in N:
		var x := i / float(N - 1)
		var y := _toe(Color(x, x, x).srgb_to_linear().r)
		offsets.append(x)
		colors.append(Color(y, y, y).linear_to_srgb())
	var gradient := Gradient.new()
	gradient.offsets = offsets
	gradient.colors = colors
	var curve := GradientTexture1D.new()
	curve.gradient = gradient
	curve.width = 256
	return curve


func _toe(x: float) -> float:
	return TOE_PIVOT * pow(x / TOE_PIVOT, TOE_POWER) if x < TOE_PIVOT else x


func _vignette(level: Node) -> void:
	var layer := CanvasLayer.new()
	layer.name = "VinetaLA"
	var rect := ColorRect.new()
	rect.name = "Vineta"
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = VIGNETTE
	material.set_shader_parameter("strength", VIGNETTE_STRENGTH)
	rect.material = material
	level.add_child(layer)
	layer.owner = level
	layer.add_child(rect)
	rect.owner = level


func _big_pot(level: Node, pot: Node3D) -> void:
	var big := (load(BIG_POT) as PackedScene).instantiate() as Node3D
	big.name = pot.name
	big.transform = pot.transform
	var parent := pot.get_parent()
	parent.remove_child(pot)
	pot.free()
	parent.add_child(big)
	big.owner = level


func _light(level: Node, room: Area3D) -> void:
	var shape := room.get_node("CollisionShape3D") as CollisionShape3D
	var floor_y := shape.position.y - (shape.shape as BoxShape3D).size.y / 2.0
	var spot := SpotLight3D.new()
	spot.name = "LuzSala"
	spot.light_color = ROOM_LIGHT_COLOR
	spot.light_energy = ROOM_LIGHT_ENERGY
	spot.spot_range = ROOM_LIGHT_HEIGHT * 2.5
	spot.spot_angle = ROOM_LIGHT_ANGLE
	spot.spot_attenuation = 0.0
	spot.spot_angle_attenuation = ROOM_LIGHT_SOFTNESS
	spot.light_specular = 0.6
	room.add_child(spot)
	spot.owner = level
	spot.position = shape.position + Vector3(0, floor_y - shape.position.y + ROOM_LIGHT_HEIGHT, ROOM_LIGHT_SOUTH)
	spot.rotation = Vector3(deg_to_rad(-90.0 + ROOM_LIGHT_TILT), 0, 0)
	var size := (shape.shape as BoxShape3D).size
	var probe := ReflectionProbe.new()
	probe.name = "ReflejoSala"
	probe.size = Vector3(size.x + MASK_MARGIN * 2.0, WALL_HEIGHT + 2.0, size.z + MASK_MARGIN * 2.0)
	probe.interior = true
	probe.box_projection = true
	probe.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	room.add_child(probe)
	probe.owner = level
	probe.position = shape.position + Vector3(0, floor_y - shape.position.y + 1.2, 0)


func _fade(level: Node, room: Area3D) -> void:
	var shape := room.get_node("CollisionShape3D") as CollisionShape3D
	var size := (shape.shape as BoxShape3D).size
	var to_level := shape.transform
	var parent := shape.get_parent() as Node
	while parent != level:
		to_level = (parent as Node3D).transform * to_level
		parent = parent.get_parent()
	var center := to_level.origin
	var floor_rect := Rect2(center.x - size.x / 2.0, center.z - size.z / 2.0, size.x, size.z)
	var material := ShaderMaterial.new()
	material.shader = FADE
	material.set_shader_parameter("inner", Vector4(floor_rect.position.x - FADE_START["o"], floor_rect.position.y - FADE_START["s"],
			floor_rect.end.x + FADE_START["e"], floor_rect.end.y + FADE_START["n"]))
	material.set_shader_parameter("outer", Vector4(floor_rect.position.x - FADE_END["o"], floor_rect.position.y - FADE_END["s"],
			floor_rect.end.x + FADE_END["e"], floor_rect.end.y + FADE_END["n"]))
	material.set_shader_parameter("floor_rect", Vector4(floor_rect.position.x, floor_rect.position.y, floor_rect.end.x, floor_rect.end.y))
	var outer := floor_rect.grow(MASK_MARGIN)
	var limit := outer.grow(0.2)
	material.set_shader_parameter("limit", Vector4(limit.position.x, limit.position.y, limit.end.x, limit.end.y))
	var floor_y := center.y - size.y / 2.0
	material.set_shader_parameter("plane_y", floor_y + WALL_HEIGHT)
	var plane := PlaneMesh.new()
	plane.size = outer.size + Vector2.ONE * PILLAR_HEIGHT * 2.0
	plane.material = material
	var veil := MeshInstance3D.new()
	veil.name = "BordeOscuro"
	veil.mesh = plane
	veil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	room.add_child(veil)
	veil.owner = level
	var local := (to_level * shape.transform.affine_inverse()).affine_inverse()
	veil.transform.origin = local * Vector3(center.x, floor_y + PILLAR_HEIGHT + 0.02, center.z)


func _stairs_kind(node: Node) -> String:
	if node.scene_file_path.ends_with("stairs_down.tscn"):
		return "baja"
	if node.scene_file_path.ends_with("stairs.tscn"):
		return "sube"
	return ""


func _shapes(grid: GridMap) -> Dictionary:
	var lib := grid.mesh_library
	var stairs := {}
	for node: Node in grid.get_parent().get_children():
		if node is Node3D and _stairs_kind(node) != "":
			stairs[grid.local_to_map(grid.transform.affine_inverse() * (node as Node3D).position)] = _stairs_kind(node)
	var open := func(cell: Vector3i) -> bool:
		var item := grid.get_cell_item(cell)
		return item != GridMap.INVALID_CELL_ITEM and lib.get_item_name(item) not in WALLS and lib.get_item_name(item) != DOOR and not stairs.has(cell)
	var out := {}
	for cell in grid.get_used_cells():
		var item_name := lib.get_item_name(grid.get_cell_item(cell))
		if item_name not in WALLS and item_name != DOOR and not stairs.has(cell):
			continue
		var code := ""
		for side: String in SIDES:
			if open.call(cell + SIDES[side]):
				code += side
		var corners := ""
		for corner: String in CORNERS:
			if not code.contains(corner[0]) and not code.contains(corner[1]) and open.call(cell + SIDES[corner[0]] + SIDES[corner[1]]):
				corners += "_" + corner
		if item_name in WALLS and code.length() == 1:
			for side: String in SIDES:
				var beside := grid.get_cell_item(cell + SIDES[side])
				if not code.contains(side) and SIDES[side] != -SIDES[code] and beside != GridMap.INVALID_CELL_ITEM and lib.get_item_name(beside) == DOOR:
					corners += "_p" + side
		var kind: String = "pared" if item_name in WALLS else stairs.get(cell, "paso")
		out[cell] = [kind, (code if code else "x") + corners]
	return out


func _kit() -> MeshLibrary:
	var kit: MeshLibrary = (load(KIT) as MeshLibrary).duplicate(true)
	for item in kit.get_item_list():
		var mesh := kit.get_item_mesh(item)
		if mesh == null:
			continue
		mesh = mesh.duplicate()
		for surface in mesh.get_surface_count():
			mesh.surface_set_material(surface, _glossy(mesh.surface_get_material(surface)))
		kit.set_item_mesh(item, mesh)
	var next := kit.get_last_unused_item_id()
	var shapes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SHAPES))
	for kind: String in KINDS:
		var source := kit.find_item_by_name(KINDS[kind][1])
		for code: String in shapes[kind]:
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			var mesh: Mesh = load(MESHES % [kind, code])
			for surface in mesh.get_surface_count():
				tool.append_from(mesh, surface, Transform3D.IDENTITY)
			tool.set_material(_glossy(STONE))
			kit.create_item(next)
			kit.set_item_name(next, KINDS[kind][0] + code)
			kit.set_item_mesh(next, tool.commit())
			kit.set_item_shapes(next, kit.get_item_shapes(source))
			kit.set_item_navigation_mesh(next, kit.get_item_navigation_mesh(source))
			next += 1
	var uid := ResourceLoader.get_resource_uid(OUT_KIT) if ResourceLoader.exists(OUT_KIT) else ResourceUID.INVALID_ID
	ResourceSaver.save(kit, OUT_KIT)
	if uid != ResourceUID.INVALID_ID:
		ResourceSaver.set_uid(OUT_KIT, uid)
	return load(OUT_KIT)


## Duplica cada línea de pared entre salas (y la del borde), para que cada sala tenga su propia pared de 2 m: corre las celdas
## y los nodos. Lo que está sobre una línea (puertas) queda en el medio de la pared doble; las escaleras, del lado de su sala.
func _spread(level: Node) -> void:
	var covered := [{}, {}]
	for room: Node in level.find_children("*", "Area3D", true, false):
		var shape := room.get_node_or_null(^"CollisionShape3D") as CollisionShape3D
		if not "map_cell" in room or shape == null or not shape.shape is BoxShape3D:
			continue
		var size := (shape.shape as BoxShape3D).size
		var center: Vector3 = (room as Node3D).position + shape.position
		for axis in 2:
			var c := center.x if axis == 0 else center.z
			var half := (size.x if axis == 0 else size.z) / 2.0
			for cell in range(ceili((c - half + 1.0) / 2.0 - 0.01), floori((c + half - 1.0) / 2.0 + 0.01) + 1):
				covered[axis][cell] = true
	var grids := level.find_children("*", "GridMap", true, false)
	var low := Vector2i(1 << 20, 1 << 20)
	var high := -low
	for grid: GridMap in grids:
		for cell in grid.get_used_cells():
			low = Vector2i(mini(low.x, cell.x), mini(low.y, cell.z))
			high = Vector2i(maxi(high.x, cell.x), maxi(high.y, cell.z))
	var seps := [[], []]
	for axis in 2:
		for cell in range(low[axis], high[axis] + 1):
			if not covered[axis].has(cell):
				seps[axis].append(cell)
	for grid: GridMap in grids:
		var old := {}
		for cell in grid.get_used_cells():
			old[cell] = [grid.get_cell_item(cell), grid.get_cell_item_orientation(cell)]
		grid.clear()
		for cell: Vector3i in old:
			for x in _copies(seps[0], cell.x):
				for z in _copies(seps[1], cell.z):
					grid.set_cell_item(Vector3i(x, cell.y, z), old[cell][0], old[cell][1])
	for floor_node: Node in level.get_children():
		for node: Node in floor_node.get_children() if floor_node.get_children().any(func(n: Node) -> bool: return n is GridMap) else []:
			if node is GridMap or not node is Node3D:
				continue
			var spot := node as Node3D
			var facing := spot.transform.basis.z
			var stairs := _stairs_kind(node) != ""
			spot.position.x = 2.0 * _shift(seps[0], spot.position.x / 2.0, facing.x if stairs else 0.0)
			spot.position.z = 2.0 * _shift(seps[1], spot.position.z / 2.0, facing.z if stairs else 0.0)
			if stairs:
				var grid := floor_node.find_children("*", "GridMap", false, false)[0] as GridMap
				var cell := grid.local_to_map(spot.position)
				grid.set_cell_item(cell - Vector3i(roundi(facing.x), 0, roundi(facing.z)), grid.mesh_library.find_item_by_name(WALLS[0]))


func _copies(seps: Array, cell: int) -> Array:
	var at := cell + seps.filter(func(s: int) -> bool: return s < cell).size()
	return [at, at + 1] if cell in seps else [at]


## Coordenada (en celdas) corrida. Sobre una línea de pared: al medio de la doble, o, con `toward`, a la copia de ese lado.
func _shift(seps: Array, u: float, toward: float) -> float:
	for s: int in seps:
		if absf(u - s) < 0.3:
			var base := s + seps.filter(func(t: int) -> bool: return t < s).size()
			if absf(toward) > 0.5:
				return base + (1.0 if toward > 0.0 else 0.0)
			return base + 0.5
	return u + seps.filter(func(t: int) -> bool: return t < u).size()
