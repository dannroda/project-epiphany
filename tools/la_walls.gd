extends SceneTree
## Paredes inclinadas a lo Link's Awakening en las mazmorras del kit chullpa (LEVELS): cada celda de pared baja en rampa hacia
## los vecinos con piso.
## export: tools/paredes_la.json con las formas que usan los niveles (luego blender -b -P tools/blender/build_paredes_la.py).
## bake: una sola vez por nivel: duplica las paredes entre salas (cada sala la suya; todo se corre con su sala), pone las
## piezas de data/kits/chullpa_la_kit.tres (kit chullpa + paredes_la.<estilo>.glb) y el look de LA.
## refresh: en el nivel ya hecho, vuelve a elegir la pieza de cada celda de pared (después de editar el nivel).
## spread: duplica las paredes entre salas de un nivel ya hecho sin duplicar (y lo guarda; después export y refresh).
## Las paredes finitas sueltas (piso a los dos lados) son paredes bajas (muro). Las celdas Puerta llevan un corte (paso) o, si tienen escalera, un corte ciego con escalones (sube, baja).
## caps: pasa a quads las tapas de las paredes en los kits ya hechos (tools/la_caps.gd) y les agrega LODs (tools/la_lods.gd), sin tocar los niveles.
## compress: comprime las mallas de los kits ya hechos (tools/la_compress.gd), sin tocar los niveles; bake, refresh y caps ya los guardan así.
## godot --headless --path . --script res://tools/la_walls.gd -- export | bake <nivel> | refresh <nivel> | spread <nivel>
## godot --path . --script res://tools/la_walls.gd -- caps | compress

const LEVELS := {"chullpa": "res://levels/chullpa.tscn", "quenoa": "res://levels/quenoa.tscn", "templo": "res://levels/templo.tscn", "totora": "res://levels/totora.tscn", "cumbre": "res://levels/cumbre.tscn",
	"bomb_cave": "res://levels/bomb_cave.tscn", "bush_cave": "res://levels/bush_cave.tscn", "grotto_cave": "res://levels/grotto_cave.tscn",
	"shrine_cave": "res://levels/shrine_cave.tscn", "spring_cave": "res://levels/spring_cave.tscn", "reflejos": "res://levels/reflejos.tscn", "huaca": "res://levels/huaca.tscn"}
## Niveles que comparten el look de otro (LOOKS).
const LOOK_OF := {"bomb_cave": "cueva", "bush_cave": "cueva", "grotto_cave": "cueva", "shrine_cave": "cueva", "spring_cave": "cueva", "reflejos": "cumbre", "huaca": "chullpa"}
## Piezas de otros kits que se pasan a las del kit chullpa (las cuevas vienen del overworld_kit).
const ADOPT := {"Cueva pared": "Pared", "Cueva piso": "Piso"}
const KIT := "res://data/kits/chullpa_kit.tres"
const OUT_KIT := "res://data/kits/chullpa_la_kit.tres"
## Marca de que el nivel ya tiene el look (bake no se repite).
const BAKED := "BrilloLA"
const SHAPES := "res://tools/paredes_la.json"
const MESHES := "res://assets/epiphany/meshes/paredes_la/%s_la_%s.res"
const STONE := preload("res://data/kits/materials/epiphany_stone.tres")
## Las paredes LA no se recortan: el cutaway sin discard (15.23).
const CUTAWAY_LA := preload("res://data/kits/shaders/cutaway_la.gdshader")
const WALLS := ["Pared", "Pared nicho", "Pared ojo"]
const DOOR := "Puerta"
## kind de la pieza → [nombre del ítem, ítem del kit de donde copia colisión y navmesh].
const KINDS := {"pared": ["Pared LA ", "Pared"], "muro": ["Muro LA ", "Pared"], "paso": ["Paso LA ", "Puerta"], "sube": ["Sube LA ", "Piso"], "baja": ["Baja LA ", "Piso"]}
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
const FOCUS := preload("res://src/world/look/enfoque_la.gd")
const FLOOR := preload("res://src/world/look/piso_la.gdshader")
## Veta de las paredes: la franja "acantilado" de la paleta (columna 3, fila 0).
const GRAIN_AMOUNT := 0.5
const GRAIN_RECT := Vector4(0.42, 0.455, 0.0, 0.25)
## Tono y AO del juego (RenderDoc); Godot hace el glow después, sobre valores ya tonemapeados.
const TONE := preload("res://src/world/look/tono_la.gd")
const AO := preload("res://src/world/look/sombra_la.gd")
## El juego usa 2, pero nuestras luces se ajustaron con exposición 1.
const TONE_EXPOSURE := 1.0
const GLOW_THRESHOLD := 0.25
## Huecos que caen al piso de abajo (DropHoles): la misma pieza con el fondo cambiado por una ventana a la sala de abajo.
const DROP_PREFIX := "Hueco caída"
const WINDOW := preload("res://src/world/look/ventana_caida.gdshader")
const HOLE_BOTTOM := -2.9
const PIT_FOG := preload("res://src/world/look/niebla_foso.gdshader")
## La niebla va sobre una copia de las paredes del foso, corrida hacia adentro.
const PIT_FOG_INSET := 0.03
const DROP_LOOK := preload("res://src/world/look/caida_la.tscn")
const CAPS := preload("res://tools/la_caps.gd")
const LODS := preload("res://tools/la_lods.gd")
const COMPRESS := preload("res://tools/la_compress.gd")
const CELL := 2.0
## Un haz cada tantos metros de hueco.
const SHAFT_SPACING := 6.0
const GLOW_INTENSITY := 0.2
const GLOSS_ROUGHNESS := 0.5
const GLOSS_SPECULAR := 0.4
## En Mobile no hay prepaso de profundidad: dibujar las paredes después del resto es más barato en el G23 (15.26).
const WALL_PRIORITY := 1
const EXPOSURE := 1.0
const BRAZIER_SCALE := 0.55
## Colgados de la cara de la pared, como en LA: a este alto y esto por delante de la roca.
const BRAZIER_HEIGHT := 1.9
const BRAZIER_SETBACK := 0.25
const BRAZIER_FLAME := 1.07
## Fuego de las antorchas como en el visor de LA: una luz chica y fuerte pegada a la llama.
const FIRE_OFFSET := Vector3(0, 0.3, 0.3)
const FIRE_ENERGY := 3.5
const FIRE_RANGE := 4.0
const FLAME := preload("res://src/world/look/llama_la.gdshader")
const GLOSS := preload("res://src/world/look/brillo_la.gd")
const FLAME_SIZE := Vector2(0.45, 0.8)
const CRACKED_WALL := "res://src/world/cracked_wall"
## Nombre de la media pared agrietada en las hojas de puerta de cada estilo (LOOKS doors).
const CRACKED_LEAF := "muro_agrietado"
## Más que esto detrás de una pared agrietada ya no es un nicho.
const NICHE_MAX_CELLS := 6
## Largo del pasillo de una puerta entre dos salas (las dos paredes de 2 m).
const DOOR_PASSAGE := 4.0
## Cámara con perspectiva como LA: la sala se ve en trapecio (abajo más ancha) y asoman las caras de los costados.
## La cámara de LA, calibrada en el visor de LA contra capturas: 65° sobre el horizonte, 28° de campo, a 23 m. La sala
## es más grande que la pantalla y la cámara se mueve adentro.
const CAMERA_PITCH := 65.0
const CAMERA_DISTANCE := 38.0
const FIELD_OF_VIEW := 28.0
## Solo se desenfoca lo que está muy alto (cerca de la cámara); lo que está más abajo que el piso no.
const FOCUS_NEAR := 9.0
const FOCUS_FAR := 2.5
## Un foco por sala que baja desde arriba, un poco desde el sur para que dé en la pared norte.
const ROOM_LIGHT_HEIGHT := 7.0
const ROOM_LIGHT_SOUTH := 1.5
const ROOM_LIGHT_TILT := 13.0
const ROOM_LIGHT_ANGLE := 75.0
## Menos de 1: el borde del foco se esfuma de a poco en vez de cortar.
const ROOM_LIGHT_SOFTNESS := 0.5
## En lugar del sol, la luz de LA que llega del lado de la cámara (el sur, en alto) y aclara las caras de las paredes.
const SUN_ELEVATION := 40.0
## Luz de cada mazmorra: ambiente de relleno, la luz del lado de la cámara (sun), el foco de cada sala (room) y el polvo que
## flota delante de la cámara, sus braseros y sus puertas (las vasijas van por escena: pot_quenoa.tscn). La Chullpa, cálida y polvorienta; la Queñoa, fría y húmeda.
const LOOKS := {
	"chullpa": {"ambient": Color(0.76, 0.7, 0.66), "ambient_energy": 1.25, "sun": Color(0.85, 0.8, 0.74), "sun_energy": 0.65,
		"room": Color(1.0, 0.87, 0.7), "room_energy": 2.3, "dust": "res://src/world/look/polvo_chullpa.tscn",
		"brazier": "res://assets/epiphany/meshes/templo_chullpa/brasero.res",
		"doors": "res://assets/epiphany/meshes/paredes_la/%s_chullpa_la.res",
		"walls": "res://assets/epiphany/meshes/paredes_la/%s_chullpa_la_%s.res", "kit": "res://data/kits/chullpa_la_kit.tres", "grain": [0.0, GRAIN_RECT],
		"floor": {"tile_size": 1.1, "jitter": 0.38, "grout_width": 0.05, "grout_shade": 0.55, "earth": 0.6, "earth_shade": 0.64}},
	"quenoa": {"ambient": Color(0.56, 0.7, 0.8), "ambient_energy": 1.35, "sun": Color(0.6, 0.8, 0.98), "sun_energy": 0.75,
		"room": Color(0.9, 0.96, 0.94), "room_energy": 2.1, "dust": "res://src/world/look/polvo_quenoa.tscn",
		"brazier": "res://assets/epiphany/meshes/objetos/brasero_quenoa.res",
		"doors": "res://assets/epiphany/meshes/paredes_la/%s_quenoa_la.res",
		"walls": "res://assets/epiphany/meshes/paredes_la/%s_quenoa_la_%s.res", "kit": "res://data/kits/quenoa_la_kit.tres", "grain": [0.6, Vector4(0.51, 0.615, 0.0, 0.25)],
		"floor": {"plank_width": 0.4, "plank_length": 2.0, "floor_color": Color(0.44, 0.26, 0.16, 1.0), "grout_width": 0.025, "grout_shade": 0.35, "tone_spread": 0.16}},
	"templo": {"ambient": Color(0.72, 0.67, 0.6), "ambient_energy": 1.0, "sun": Color(0.98, 0.93, 0.82), "sun_energy": 0.6,
		"room": Color(1.0, 0.9, 0.8), "room_energy": 1.7, "dust": "res://src/world/look/polvo_chullpa.tscn",
		"brazier": "res://assets/epiphany/meshes/templo/brasero.res",
		"doors": "res://assets/epiphany/meshes/paredes_la/%s_templo_la.res",
		"walls": "res://assets/epiphany/meshes/paredes_la/%s_templo_la_%s.res", "kit": "res://data/kits/templo_la_kit.tres", "grain": [0.0, GRAIN_RECT],
		"camera": 25.0, "reach": Vector4(0.7, 1.5, 0.7, 0.6),
		"floor": {"tile_size": 1.0, "jitter": 0.0, "grout_width": 0.035, "grout_shade": 0.55, "tone_spread": 0.08, "crack_amount": 0.08,
			"floor_color": Color(0.5, 0.43, 0.33, 0.95)}},
	"totora": {"ambient": Color(0.6, 0.72, 0.74), "ambient_energy": 1.2, "sun": Color(0.78, 0.9, 0.94), "sun_energy": 0.7,
		"room": Color(0.98, 0.95, 0.84), "room_energy": 2.0, "dust": "res://src/world/look/polvo_quenoa.tscn",
		"brazier": "res://assets/epiphany/meshes/templo_chullpa/brasero.res",
		"doors": "res://assets/epiphany/meshes/paredes_la/%s_totora_la.res",
		"walls": "res://assets/epiphany/meshes/paredes_la/%s_totora_la_%s.res", "kit": "res://data/kits/totora_la_kit.tres", "grain": [0.0, GRAIN_RECT],
		"water": true,
		"floor": {"plank_width": 0.25, "plank_length": 2.0, "floor_color": Color(0.6, 0.55, 0.4, 1.0), "grout_width": 0.02, "grout_shade": 0.45, "tone_spread": 0.12}},
	"cumbre": {"ambient": Color(0.66, 0.72, 0.84), "ambient_energy": 1.3, "sun": Color(0.86, 0.92, 1.0), "sun_energy": 0.8,
		"room": Color(1.0, 0.94, 0.82), "room_energy": 2.0, "dust": "res://src/world/look/polvo_cumbre.tscn",
		"brazier": "res://assets/epiphany/meshes/templo/brasero.res",
		"doors": "res://assets/epiphany/meshes/paredes_la/%s_cumbre_la.res",
		"walls": "res://assets/epiphany/meshes/paredes_la/%s_cumbre_la_%s.res", "kit": "res://data/kits/cumbre_la_kit.tres", "grain": [0.0, GRAIN_RECT],
		"spread": false,
		"floor": {"tile_size": 1.0, "jitter": 0.22, "grout_width": 0.05, "grout_shade": 0.42, "floor_color": Color(0.34, 0.37, 0.43, 1.0), "snow": 0.4, "ice": 0.22}},
	"cueva": {"ambient": Color(0.48, 0.5, 0.6), "ambient_energy": 0.85, "sun": Color(0.66, 0.7, 0.82), "sun_energy": 0.4,
		"room": Color(0.98, 0.86, 0.7), "room_energy": 1.6, "dust": "res://src/world/look/polvo_quenoa.tscn",
		"brazier": "res://assets/epiphany/meshes/templo_chullpa/brasero.res",
		"doors": "res://assets/epiphany/meshes/paredes_la/%s_la.res", "cracked": "res://assets/epiphany/meshes/paredes_la/%s_cueva_la.res",
		"walls": "res://assets/epiphany/meshes/paredes_la/%s_cueva_la_%s.res", "kit": "res://data/kits/cueva_la_kit.tres", "grain": [0.0, GRAIN_RECT],
		"floor": {"tile_size": 0.6, "jitter": 0.4, "grout_width": 0.04, "bevel": 0.06, "earth": 0.78, "earth_shade": 0.55,
			"floor_color": Color(0.32, 0.27, 0.24, 1.0)}},
}
## El polvo va colgado de la cámara, a esta distancia por delante (más cerca que el player).
const DUST_AHEAD := 20.0
## Hojas de las puertas de la mazmorra que se está armando (LOOKS); %s es el nombre de Door.LEAVES.
var _door_leaves := ""
## Lo mismo para la pared agrietada, si el look no la saca de las puertas (cracked).
var _cracked_leaves := ""
var _walls := MESHES
var _out_kit := OUT_KIT
var _floor_params := {}
var _grain: Array = [GRAIN_AMOUNT, GRAIN_RECT]
## Las celdas vacías dentro de una sala (o entre dos) son agua honda y cuentan como piso (LOOKS water).
var _water := false
## Distancia de la cámara (salas más chicas, cámara más cerca) y desde dónde todo es negro más allá de la pared (LOOKS).
var _camera := CAMERA_DISTANCE


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var mode := args[0] if not args.is_empty() else "export"
	if mode == "export":
		var codes := {}
		for kind: String in KINDS:
			codes[kind] = {}
		for key: String in LEVELS:
			var path: String = LEVELS[key]
			_water = LOOKS[LOOK_OF.get(key, key)].get("water", false)
			var level := _load(path)
			for grid: GridMap in level.find_children("*", "GridMap", true, false):
				for shape: Array in _shapes(grid).values():
					codes[shape[0]][shape[1]] = true
			level.free()
		var out := {}
		for kind: String in codes:
			out[kind] = codes[kind].keys()
			out[kind].sort()
		FileAccess.open(SHAPES, FileAccess.WRITE).store_string(JSON.stringify(out, "\t") + "\n")
		print(SHAPES, ": ", out)
		quit()
		return
	if mode in ["caps", "compress"]:
		if DisplayServer.get_name() == "headless":
			push_error("caps y compress necesitan el renderer (sin --headless): headless los shaders embebidos se guardan sin parámetros")
			quit(1)
			return
		var kits := {}
		for look: Dictionary in LOOKS.values():
			kits[look.kit] = true
		for kit_path: String in kits:
			var kit: MeshLibrary = load(kit_path)
			if mode == "caps":
				CAPS.apply(kit, _wall_prefixes(), _caps_path(kit_path))
				LODS.apply(kit, _wall_prefixes())
			_save_kit(kit, kit_path)
		quit()
		return
	var path: String = LEVELS.get(args[1] if args.size() > 1 else "", "")
	if path == "" or mode not in ["bake", "refresh", "spread"]:
		push_error("uso: -- export | bake <nivel> | refresh <nivel> | spread <nivel>, con nivel en %s" % [LEVELS.keys()])
		quit(1)
		return
	if DisplayServer.get_name() == "headless":
		push_error("bake y refresh necesitan el renderer (sin --headless): headless los shaders embebidos se guardan sin parámetros")
		quit(1)
		return
	if mode == "spread":
		var baked := _load(path)
		_spread(baked)
		_save(baked, path)
		quit()
		return
	var look: Dictionary = LOOKS[LOOK_OF.get(args[1], args[1])]
	_door_leaves = look.doors
	_cracked_leaves = look.get("cracked", look.doors)
	_walls = look.walls
	_out_kit = look.kit
	_floor_params = look.floor
	_grain = look.grain
	_water = look.get("water", false)
	_camera = look.get("camera", CAMERA_DISTANCE)
	var level := _load(path)
	if mode == "bake" and level.has_node(NodePath(BAKED)):
		push_error("%s ya tiene el look de LA: usar refresh" % path)
		level.free()
		quit(1)
		return
	var kit := _kit()
	var missing := {}
	for grid: GridMap in level.find_children("*", "GridMap", true, false):
		for shape: Array in _shapes(grid).values():
			if kit.find_item_by_name(KINDS[shape[0]][0] + shape[1]) < 0:
				missing[KINDS[shape[0]][0] + shape[1]] = true
	if not missing.is_empty():
		push_error("faltan piezas en el kit (export y build_paredes_la.py): %s" % [missing.keys()])
		level.free()
		quit(1)
		return
	for grid: GridMap in level.find_children("*", "GridMap", true, false):
		_prune(grid)
		var cells := _shapes(grid)
		for cell in grid.get_used_cells():
			var adopted: String = ADOPT.get(grid.mesh_library.get_item_name(grid.get_cell_item(cell)), "")
			if adopted != "" and not cells.has(cell):
				grid.set_cell_item(cell, kit.find_item_by_name(adopted), grid.get_cell_item_orientation(cell))
		grid.mesh_library = kit
		for cell: Vector3i in cells:
			var shape: Array = cells[cell]
			grid.set_cell_item(cell, kit.find_item_by_name(KINDS[shape[0]][0] + shape[1]))
		_face_chests(grid)
	_drops(level, kit)
	if mode == "bake":
		_dress(level)
	else:
		var veils: Array[Node] = []
		for node: Node in level.find_children("*", "", true, false):
			if node.scene_file_path.ends_with("door.tscn"):
				_door(level, node)
			elif node.scene_file_path.begins_with(CRACKED_WALL):
				_cracked_wall(level, node)
			elif node is Area3D and "map_cell" in node and node.has_node(^"BordeOscuro"):
				veils.append(node.get_node(^"BordeOscuro"))
		for veil in veils:
			veil.get_parent().remove_child(veil)
			veil.free()
	_look(level, look)
	_save(level, path)
	quit()


func _save(level: Node, path: String) -> void:
	var packed := PackedScene.new()
	packed.pack(level)
	var uid := ResourceLoader.get_resource_uid(path)
	print(path, ": ", error_string(ResourceSaver.save(packed, path)))
	ResourceSaver.set_uid(path, uid)
	_pin_ext_uids(path)
	level.free()


## El nivel, con las paredes ya duplicadas (si todavía no tiene el look, las duplica en memoria).
func _load(path: String) -> Node:
	var level: Node = (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	var key: String = LEVELS.find_key(path)
	if not level.has_node(NodePath(BAKED)) and LOOKS[LOOK_OF.get(key, key)].get("spread", true):
		_spread(level)
	return level


## Antorchas a braseros sobre el borde, puertas a la medida del corte, sin los escalones viejos y la cámara casi sin perspectiva.
func _dress(level: Node) -> void:
	var gloss := Node.new()
	gloss.name = "BrilloLA"
	gloss.set_script(GLOSS)
	level.add_child(gloss)
	gloss.owner = level
	for node: Node in level.find_children("*", "", true, false):
		var path := node.scene_file_path
		if path.ends_with("wall_torch.tscn"):
			var torch := node as Node3D
			var facing := torch.transform.basis.z.normalized()
			var side := "s" if facing.z > 0.5 else "n" if facing.z < -0.5 else "e" if facing.x > 0.5 else "o"
			torch.position = torch.position - facing * (WALL_RUN[side] * BRAZIER_HEIGHT / WALL_HEIGHT - BRAZIER_SETBACK)
			torch.position.y = BRAZIER_HEIGHT
			var model := torch.get_node("Model") as MeshInstance3D
			model.position = Vector3.ZERO
			model.scale = Vector3.ONE * BRAZIER_SCALE
			for part: String in ["Flame", "Light"]:
				torch.get_node(part).position = Vector3(0, BRAZIER_FLAME * BRAZIER_SCALE, 0)
			var flame := torch.get_node("Flame") as MeshInstance3D
			var quad := QuadMesh.new()
			quad.size = FLAME_SIZE
			quad.center_offset = Vector3(0, FLAME_SIZE.y * 0.4, 0)
			var flame_material := ShaderMaterial.new()
			flame_material.shader = FLAME
			quad.material = flame_material
			flame.mesh = quad
			var fire := torch.get_node("Light") as OmniLight3D
			fire.position += FIRE_OFFSET
			fire.light_energy = FIRE_ENERGY
			fire.omni_range = FIRE_RANGE
			fire.omni_attenuation = 1.0
			(torch.get_node("Glow") as Node3D).visible = false
			level.set_editable_instance(torch, true)
		elif path.ends_with("door.tscn"):
			_door(level, node)
		elif path.begins_with(CRACKED_WALL):
			_cracked_wall(level, node)
		elif _stairs_kind(node) != "":
			(node.get_node("Visual") as Node3D).visible = false
			level.set_editable_instance(node, true)
		elif node is Area3D and "map_cell" in node:
			_light(level, node as Area3D)
		elif node is WorldEnvironment:
			var env := (node as WorldEnvironment).environment.duplicate() as Environment
			env.background_color = Color.BLACK
			env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
			env.tonemap_exposure = EXPOSURE
			env.reflected_light_source = Environment.REFLECTION_SOURCE_BG
			env.adjustment_enabled = false
			env.glow_enabled = true
			env.glow_intensity = GLOW_INTENSITY
			env.glow_bloom = 0.0
			env.glow_hdr_threshold = GLOW_THRESHOLD
			env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
			env.ssao_enabled = false
			(node as WorldEnvironment).environment = env
			var compositor := Compositor.new()
			var tone := TONE.new()
			tone.exposure = TONE_EXPOSURE
			compositor.compositor_effects = [AO.new(), tone]
			(node as WorldEnvironment).compositor = compositor
		elif node is DirectionalLight3D:
			var sun := node as DirectionalLight3D
			sun.rotation = Vector3(deg_to_rad(-SUN_ELEVATION), 0, 0)
			sun.shadow_enabled = false
		elif node is Camera3D and "cuts_south_wall" in node:
			var pitch := deg_to_rad(CAMERA_PITCH)
			node.set("offset", Vector3(0, sin(pitch), cos(pitch)) * _camera)
			var blur := CameraAttributesPractical.new()
			blur.dof_blur_far_enabled = false
			blur.dof_blur_far_distance = _camera + FOCUS_FAR
			blur.dof_blur_far_transition = 6.0
			blur.dof_blur_near_enabled = true
			blur.dof_blur_near_distance = _camera - FOCUS_NEAR
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


## Como en LA, la piedra y el piso brillan un poco y reflejan la sala (sondas de reflejo por sala).
var _glossy_cache := {}


func _glossy(material: Material) -> Material:
	if not material is ShaderMaterial or not "cutaway" in (material as ShaderMaterial).shader.resource_path:
		return material
	if not _glossy_cache.has(material):
		var copy := material.duplicate() as ShaderMaterial
		copy.shader = CUTAWAY_LA
		copy.render_priority = WALL_PRIORITY
		copy.set_shader_parameter("roughness", GLOSS_ROUGHNESS)
		copy.set_shader_parameter("specular", GLOSS_SPECULAR)
		_glossy_cache[material] = copy
	return _glossy_cache[material]


var _wood_material: ShaderMaterial


func _wood() -> ShaderMaterial:
	if _wood_material == null:
		_wood_material = _glossy(STONE).duplicate()
		_wood_material.set_shader_parameter("grain_amount", _grain[0])
		_wood_material.set_shader_parameter("grain_rect", _grain[1])
	return _wood_material


func _floor(material: Material) -> Material:
	if not material is BaseMaterial3D:
		return material
	if not _glossy_cache.has(material):
		var tiles := ShaderMaterial.new()
		tiles.shader = FLOOR
		tiles.set_shader_parameter("albedo_texture", (material as BaseMaterial3D).albedo_texture)
		tiles.set_shader_parameter("albedo_color", (material as BaseMaterial3D).albedo_color)
		tiles.set_shader_parameter("roughness", GLOSS_ROUGHNESS)
		tiles.set_shader_parameter("specular", GLOSS_SPECULAR)
		for param: String in _floor_params:
			tiles.set_shader_parameter(param, _floor_params[param])
		_glossy_cache[material] = tiles
	return _glossy_cache[material]


## Colores y fuerza de las luces de la mazmorra y el polvo (una escena por mazmorra, para ajustarla a ojo); se vuelve a aplicar en cada refresh.
func _look(level: Node, look: Dictionary) -> void:
	var cameras: Array[Node] = []
	for node: Node in level.find_children("*", "", true, false):
		if node is WorldEnvironment:
			var env := (node as WorldEnvironment).environment
			env.ambient_light_color = look.ambient
			env.ambient_light_energy = look.ambient_energy
		elif node is DirectionalLight3D:
			(node as DirectionalLight3D).light_color = look.sun
			(node as DirectionalLight3D).light_energy = look.sun_energy
		elif node is SpotLight3D and node.name == "LuzSala":
			(node as SpotLight3D).light_color = look.room
			(node as SpotLight3D).light_energy = look.room_energy
		elif node is Camera3D and "cuts_south_wall" in node:
			cameras.append(node)
		elif node.scene_file_path.ends_with("wall_torch.tscn"):
			(node.get_node("Model") as MeshInstance3D).mesh = load(look.brazier)
	for camera: Node in cameras:
		var old := camera.get_node_or_null("Polvo")
		if old and old.scene_file_path == look.dust:
			continue
		if old:
			camera.remove_child(old)
			old.free()
		var dust := (load(look.dust) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
		dust.position = Vector3(0, 0, -DUST_AHEAD)
		camera.add_child(dust)
		dust.owner = level


func _light(level: Node, room: Area3D) -> void:
	var shape := room.get_node("CollisionShape3D") as CollisionShape3D
	var floor_y := shape.position.y - (shape.shape as BoxShape3D).size.y / 2.0
	var spot := SpotLight3D.new()
	spot.name = "LuzSala"
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


func _room_rects(grid: GridMap) -> Array[Rect2]:
	var level: Node = grid
	while level.get_parent() != null:
		level = level.get_parent()
	var to_grid := Transform3D.IDENTITY
	var node: Node = grid
	while node != level:
		to_grid = (node as Node3D).transform * to_grid
		node = node.get_parent()
	to_grid = to_grid.affine_inverse()
	var rects: Array[Rect2] = []
	for room: Node in level.find_children("*", "Area3D", true, false):
		var shape := room.get_node_or_null(^"CollisionShape3D") as CollisionShape3D
		if not "map_cell" in room or shape == null or not shape.shape is BoxShape3D:
			continue
		var to_level := shape.transform
		node = room
		while node != level:
			to_level = (node as Node3D).transform * to_level
			node = node.get_parent()
		var center := to_grid * to_level.origin
		var size := (shape.shape as BoxShape3D).size
		rects.append(Rect2(center.x - size.x / 2.0, center.z - size.z / 2.0, size.x, size.z).grow(-0.5))
	return rects


## Largo del paso de una puerta: DOOR_PASSAGE entre paredes duplicadas, una celda en una pared fina entre dos salas.
func _passage(door: Node3D) -> float:
	var grids := door.get_parent().find_children("*", "GridMap", false, false)
	if grids.is_empty():
		return DOOR_PASSAGE
	var grid := grids[0] as GridMap
	var lib := grid.mesh_library
	var ahead := door.transform.basis.z.normalized() * (CELL * 0.75)
	for at: Vector3 in [door.position + ahead, door.position - ahead]:
		var item := grid.get_cell_item(grid.local_to_map(grid.transform.affine_inverse() * at))
		if item != GridMap.INVALID_CELL_ITEM and (_base_name(lib.get_item_name(item)) in WALLS or _base_name(lib.get_item_name(item)) == DOOR):
			return DOOR_PASSAGE
	return CELL


## La caja de una sala en coordenadas del nivel (vacía si no es una sala).
func _room_box(level: Node, room: Node) -> AABB:
	var shape := room.get_node_or_null(^"CollisionShape3D") as CollisionShape3D
	if not "map_cell" in room or shape == null or not shape.shape is BoxShape3D:
		return AABB()
	var to_level := shape.transform
	var node: Node = room
	while node != level:
		to_level = (node as Node3D).transform * to_level
		node = node.get_parent()
	var size := (shape.shape as BoxShape3D).size
	return AABB(to_level.origin - size / 2.0, size)


func _room_of(rooms: Array[Rect2], at: Vector3) -> int:
	for i in rooms.size():
		if rooms[i].has_point(Vector2(at.x, at.z)):
			return i
	return -1


func _stairs_kind(node: Node) -> String:
	if node.scene_file_path.ends_with("stairs_down.tscn"):
		return "baja"
	if node.scene_file_path.ends_with("stairs.tscn"):
		return "sube"
	return ""


## Saca las paredes de relleno a más de dos celdas de cualquier piso: fuera de las salas queda el fondo negro, salvo el
## reborde de una celda que rodea las paredes de afuera (el techo).
func _prune(grid: GridMap) -> void:
	var lib := grid.mesh_library
	var rooms := _room_rects(grid)
	var stairs := {}
	for node: Node in grid.get_parent().get_children():
		if node is Node3D and _stairs_kind(node) != "":
			stairs[grid.local_to_map(grid.transform.affine_inverse() * (node as Node3D).position)] = true
	var wall := func(cell: Vector3i) -> bool:
		var item := grid.get_cell_item(cell)
		return item != GridMap.INVALID_CELL_ITEM and _base_name(lib.get_item_name(item)) in WALLS and not stairs.has(cell)
	var lone: Array[Vector3i] = []
	for cell in grid.get_used_cells():
		if not wall.call(cell):
			continue
		var touches := false
		for dx in range(-2, 3):
			for dz in range(-2, 3):
				var next := cell + Vector3i(dx, 0, dz)
				if next == cell or wall.call(next):
					continue
				if grid.get_cell_item(next) != GridMap.INVALID_CELL_ITEM or stairs.has(next) or (_water and _room_of(rooms, grid.map_to_local(next)) >= 0):
					touches = true
		if not touches:
			lone.append(cell)
	var set := {}
	for cell in lone:
		set[cell] = true
	for cell in lone:
		var rim := false
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				var next := cell + Vector3i(dx, 0, dz)
				rim = rim or (wall.call(next) and not set.has(next))
		if not rim:
			grid.set_cell_item(cell, GridMap.INVALID_CELL_ITEM)


func _shapes(grid: GridMap) -> Dictionary:
	var lib := grid.mesh_library
	var stairs := {}
	for node: Node in grid.get_parent().get_children():
		if node is Node3D and _stairs_kind(node) != "":
			stairs[grid.local_to_map(grid.transform.affine_inverse() * (node as Node3D).position)] = _stairs_kind(node)
	var rooms := _room_rects(grid)
	var floor := func(cell: Vector3i) -> bool:
		var item := grid.get_cell_item(cell)
		if item == GridMap.INVALID_CELL_ITEM:
			if not _water:
				return false
			if _room_of(rooms, grid.map_to_local(cell)) >= 0:
				return true
			for pair in [["n", "s"], ["e", "o"]]:
				if _room_of(rooms, grid.map_to_local(cell + SIDES[pair[0]])) >= 0 and _room_of(rooms, grid.map_to_local(cell + SIDES[pair[1]])) >= 0:
					return true
			return false
		return _base_name(lib.get_item_name(item)) not in WALLS and _base_name(lib.get_item_name(item)) != DOOR and not stairs.has(cell)
	var thin := {}
	for cell in grid.get_used_cells():
		if _base_name(lib.get_item_name(grid.get_cell_item(cell))) in WALLS and not stairs.has(cell):
			var code := _sides(cell, floor)
			var splits := func(a: String, b: String) -> bool:
				var one := _room_of(rooms, grid.map_to_local(cell + SIDES[a]))
				return code.contains(a) and code.contains(b) and one >= 0 and _room_of(rooms, grid.map_to_local(cell + SIDES[b])) not in [-1, one]
			if ((code.contains("e") and code.contains("o")) or (code.contains("n") and code.contains("s"))) and not splits.call("e", "o") and not splits.call("n", "s"):
				thin[cell] = code
	var open := func(cell: Vector3i) -> bool:
		return thin.has(cell) or floor.call(cell)
	var out := {}
	for cell in grid.get_used_cells():
		var item_name := _base_name(lib.get_item_name(grid.get_cell_item(cell)))
		if item_name not in WALLS and item_name != DOOR and not stairs.has(cell):
			continue
		if thin.has(cell):
			out[cell] = ["muro", thin[cell]]
			continue
		var code := _sides(cell, open)
		var corners := ""
		for corner: String in CORNERS:
			if not code.contains(corner[0]) and not code.contains(corner[1]) and open.call(cell + SIDES[corner[0]] + SIDES[corner[1]]):
				corners += "_" + corner
		if item_name in WALLS and code.length() == 1:
			for side: String in SIDES:
				var beside := grid.get_cell_item(cell + SIDES[side])
				if not code.contains(side) and SIDES[side] != -SIDES[code] and beside != GridMap.INVALID_CELL_ITEM and _base_name(lib.get_item_name(beside)) == DOOR:
					corners += "_p" + side
		var kind: String = "pared" if item_name in WALLS else stairs.get(cell, "paso")
		out[cell] = [kind, (code if code else "x") + corners]
	return out


## La puerta llena el pasillo de la pared doble: la colisión lo cubre entero y hay una hoja LA del alto de la pared en la
## cara de cada sala (la de atrás girada), inclinada como esa pared.
func _door(level: Node, door: Node) -> void:
	var depth := _passage(door as Node3D)
	door.set("depth", depth)
	door.set("leaf_meshes", _door_leaves)
	door.set("sink", WALL_HEIGHT + 0.2)
	var leaves: Dictionary = door.get_script().get_script_constant_map()["LEAVES"]
	var mesh: Mesh = load(_door_leaves % leaves[door.get("kind")])
	var face := depth / 2.0 - mesh.get_aabb().end.z
	var front := door.get_node("Leaf/LeafMesh") as MeshInstance3D
	var back := door.get_node_or_null("Leaf/LeafBackLA") as MeshInstance3D
	if back == null:
		back = MeshInstance3D.new()
		back.name = "LeafBackLA"
		door.get_node("Leaf").add_child(back)
		back.owner = level
	back.material_overlay = front.material_overlay
	for leaf: MeshInstance3D in [front, back]:
		var turn := Basis() if leaf == front else Basis(Vector3.UP, PI)
		var out := ((door as Node3D).transform.basis * turn * Vector3.BACK).normalized()
		var side := "s" if out.z > 0.5 else "n" if out.z < -0.5 else "e" if out.x > 0.5 else "o"
		var lean := Basis(Vector3.RIGHT, Vector3(0, 1, -WALL_RUN[side] / WALL_HEIGHT), Vector3.BACK)
		leaf.mesh = mesh
		leaf.transform = Transform3D(turn * lean, turn * Vector3(0, 0, face))
	level.set_editable_instance(door, true)


## La pared agrietada tapa el paso entero, inclinada en cada cara como su pared (así no se ve el nicho de atrás): la
## variante del fondo del paso y, si una cara mira al norte, con esa cara atrás.
func _cracked_wall(level: Node, wall: Node) -> void:
	var depth := _wall_depth(level, wall as Node3D)
	var out := ((wall as Node3D).transform.basis * Vector3.BACK).normalized()
	var front := _facing(out)
	var back := _facing(-out)
	var variant := "4" if depth > 3.0 else "2"
	var turn := Basis()
	if _between_low_walls(wall as Node3D):
		variant = "bajo"
	elif WALL_RUN[front] != WALL_RUN[back]:
		variant += "n"
		if WALL_RUN[front] > WALL_RUN[back]:
			turn = Basis(Vector3.UP, PI)
	var path := (_cracked_leaves % CRACKED_LEAF).trim_suffix(".res") + "_%s.res" % variant
	if not ResourceLoader.exists(path):
		push_warning("%s: falta %s" % [wall.name, path])
		return
	var model := wall.get_node("Wall/Model") as MeshInstance3D
	model.mesh = load(path)
	model.transform = Transform3D(turn, Vector3.ZERO)
	level.set_editable_instance(wall, true)
	_niche_roof(level, wall as Node3D)


## Techo del color de las crestas sobre el nicho que esconde (piso encerrado detrás, en la misma sala): la pared lo
## lleva en `covers` y se va al romperla. Si atrás hay otra sala o un paso, no hace falta.
func _niche_roof(level: Node, wall: Node3D) -> void:
	var parent := wall.get_parent() as Node3D
	var roof_name := String(wall.name).trim_suffix("CrackedWall") + "NicheRoof"
	var roof := parent.get_node_or_null(NodePath(roof_name)) as MeshInstance3D
	var path := NodePath("../" + roof_name)
	var covers: Array[NodePath] = []
	for cover: NodePath in wall.get(&"covers"):
		if cover != path:
			covers.append(cover)
	wall.set(&"covers", covers)
	var grids := parent.find_children("*", "GridMap", false, false)
	if grids.is_empty():
		return
	var grid := grids[0] as GridMap
	var cells := _niche_cells(level, wall, grid)
	if cells.is_empty():
		if roof:
			roof.mesh = null
			roof.visible = false
		return
	var crest := _crest(grid.mesh_library)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_normal(Vector3.UP)
	tool.set_uv(crest[1])
	var height := grid.transform.origin.y + WALL_HEIGHT + 0.02
	var half := CELL / 2.0 + 0.05
	var quads: Array[Rect2] = []
	for cell: Vector3i in cells:
		var center := grid.transform * grid.map_to_local(cell)
		var lo := center - Vector3(half, 0, half)
		var hi := center + Vector3(half, 0, half)
		for side: Vector3i in SIDES.values():
			if cell + side in cells or grid.get_cell_item(cell + side) == GridMap.INVALID_CELL_ITEM:
				continue
			var run: float = WALL_RUN[_facing(-Vector3(side))]
			lo = lo.min(lo + Vector3(side) * run)
			hi = hi.max(hi + Vector3(side) * run)
		quads.append(Rect2(lo.x, lo.z, hi.x - lo.x, hi.z - lo.z))
	var out := (wall.transform.basis * Vector3.BACK).normalized().round()
	var niche_edge := grid.transform * grid.map_to_local(cells[0]) + out * CELL / 2.0
	var at := grid.transform * grid.map_to_local(grid.local_to_map(grid.transform.affine_inverse() * wall.position))
	var face_top: Vector3 = at + out * (CELL / 2.0 - WALL_RUN[_facing(out)])
	var side := Vector3(absf(out.z), 0, absf(out.x)) * half
	var lo := niche_edge.min(face_top) - side
	var hi := niche_edge.max(face_top) + side
	quads.append(Rect2(lo.x, lo.z, hi.x - lo.x, hi.z - lo.z))
	for quad in quads:
		var a := Vector3(quad.position.x, height, quad.position.y)
		var b := Vector3(quad.end.x, height, quad.position.y)
		var c := Vector3(quad.end.x, height, quad.end.y)
		var d := Vector3(quad.position.x, height, quad.end.y)
		for v: Vector3 in [a, b, c, a, c, d]:
			tool.add_vertex(v)
	tool.set_material(crest[0])
	if roof == null:
		roof = MeshInstance3D.new()
		roof.name = roof_name
		parent.add_child(roof)
		roof.owner = level
	roof.mesh = tool.commit()
	roof.visible = true
	roof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	covers.append(path)
	wall.set(&"covers", covers)


## El piso encerrado detrás de la pared, si está en la misma sala que el frente (un bolsillo de la sala).
func _niche_cells(level: Node, wall: Node3D, grid: GridMap) -> Array[Vector3i]:
	var none: Array[Vector3i] = []
	var lib := grid.mesh_library
	var is_floor := func(cell: Vector3i) -> bool:
		var item := grid.get_cell_item(cell)
		if item == GridMap.INVALID_CELL_ITEM:
			return false
		var piece := lib.get_item_name(item)
		return not (piece.begins_with("Pared") or piece.begins_with("Muro") or piece.begins_with("Paso"))
	var at := grid.local_to_map(grid.transform.affine_inverse() * wall.position)
	var back := Vector3i((wall.transform.basis * Vector3.FORWARD).normalized().round())
	var start := at + back
	if not is_floor.call(start):
		start += back
	if not is_floor.call(start):
		return none
	var to_level := _level_transform(level, grid.get_parent() as Node3D)
	var rooms := _rooms_at(level, to_level * (grid.transform * grid.map_to_local(start)))
	var front := _rooms_at(level, to_level * (wall.position + wall.transform.basis * Vector3.BACK * CELL))
	if rooms.is_empty() or rooms != front:
		return none
	var cells: Array[Vector3i] = [start]
	var index := 0
	while index < cells.size():
		for side: Vector3i in SIDES.values():
			var next: Vector3i = cells[index] + side
			if next != at and not next in cells and is_floor.call(next):
				cells.append(next)
		index += 1
		if cells.size() > NICHE_MAX_CELLS:
			return none
	return cells


func _rooms_at(level: Node, at: Vector3) -> Array[Node]:
	var out: Array[Node] = []
	for room: Node in level.find_children("*", "Area3D", true, false):
		var box := _room_box(level, room)
		if box.size != Vector3.ZERO and absf(box.position.y - at.y) < 1.5 and Rect2(box.position.x, box.position.z, box.size.x, box.size.z).has_point(Vector2(at.x, at.z)):
			out.append(room)
	return out


func _level_transform(level: Node, node: Node3D) -> Transform3D:
	var out := Transform3D.IDENTITY
	while node != level:
		out = node.transform * out
		node = node.get_parent() as Node3D
	return out


## Material de las paredes y la UV de su cresta (la cara de arriba).
func _crest(kit: MeshLibrary) -> Array:
	var mesh := kit.get_item_mesh(kit.find_item_by_name(KINDS["pared"][0] + "n")) as ArrayMesh
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var uv := Vector2.ZERO
	for i in vertices.size():
		if normals[i].y > 0.9 and vertices[i].y > WALL_HEIGHT - 0.05:
			uv = uvs[i]
			break
	return [mesh.surface_get_material(0), uv]


## Está en un hueco de una pared baja (los setos de la Queñoa): a los costados hay Muro LA.
func _between_low_walls(wall: Node3D) -> bool:
	var grids := wall.get_parent().find_children("*", "GridMap", false, false)
	if grids.is_empty():
		return false
	var grid := grids[0] as GridMap
	var side := wall.transform.basis.x.normalized() * CELL
	for at: Vector3 in [wall.position + side, wall.position - side]:
		var item := grid.get_cell_item(grid.local_to_map(grid.transform.affine_inverse() * at))
		if item == GridMap.INVALID_CELL_ITEM or not grid.mesh_library.get_item_name(item).begins_with(KINDS["muro"][0]):
			return false
	return true


func _facing(out: Vector3) -> String:
	return "s" if out.z > 0.5 else "n" if out.z < -0.5 else "e" if out.x > 0.5 else "o"


## Fondo de la pared en la que está: el doble de lo que hay hasta la cara de la sala más cercana a lo largo del paso.
func _wall_depth(level: Node, wall: Node3D) -> float:
	var to_level := wall.transform
	var node := wall.get_parent()
	while node != level:
		to_level = (node as Node3D).transform * to_level
		node = node.get_parent()
	var at := to_level.origin
	var across_x := absf(to_level.basis.z.x) > absf(to_level.basis.z.z)
	var nearest := INF
	for room: Node in level.find_children("*", "Area3D", true, false):
		var box := _room_box(level, room)
		if box.size == Vector3.ZERO or absf(box.position.y - at.y) > 1.0:
			continue
		var along := at.z if across_x else at.x
		var lo := box.position.z if across_x else box.position.x
		if along < lo or along > lo + (box.size.z if across_x else box.size.x):
			continue
		var c := at.x if across_x else at.z
		var start := box.position.x if across_x else box.position.z
		var end := box.end.x if across_x else box.end.z
		if c < start:
			nearest = minf(nearest, start - c)
		elif c > end:
			nearest = minf(nearest, c - end)
	return nearest * 2.0 if nearest < DOOR_PASSAGE else _passage(wall)


## Los cofres miran al sur (a la cámara); el que tiene pared al sur (en un nicho) mira al lado por donde se llega.
func _face_chests(grid: GridMap) -> void:
	for node: Node in grid.get_parent().get_children():
		if not (node is Node3D and node.scene_file_path.ends_with("chest.tscn")):
			continue
		var chest := node as Node3D
		var cell := grid.local_to_map(grid.transform.affine_inverse() * chest.position)
		var side := "s"
		for candidate: String in ["s", "n", "e", "o"]:
			var item := grid.get_cell_item(cell + SIDES[candidate])
			if item != GridMap.INVALID_CELL_ITEM and grid.mesh_library.get_item_name(item).begins_with("Piso"):
				side = candidate
				break
		chest.basis = Basis(Vector3.UP, Vector3.BACK.signed_angle_to(Vector3(SIDES[side]), Vector3.UP))


func _sides(cell: Vector3i, open: Callable) -> String:
	var code := ""
	for side: String in SIDES:
		if open.call(cell + SIDES[side]):
			code += side
	return code


## El ítem del kit chullpa que una pieza LA reemplaza: Pared LA … es una pared, Paso LA …, Sube LA … y Baja LA … una puerta.
func _base_name(item_name: String) -> String:
	item_name = ADOPT.get(item_name, item_name)
	if item_name.begins_with(KINDS["pared"][0]) or item_name.begins_with(KINDS["muro"][0]):
		return WALLS[0]
	for kind: String in ["paso", "sube", "baja"]:
		if item_name.begins_with(KINDS[kind][0]):
			return DOOR
	return item_name


## Cada pieza conserva su número entre corridas y las que ya no se usan quedan: MeshLibrary no guarda ítems con números
## salteados.
func _kit() -> MeshLibrary:
	var kit: MeshLibrary = (load(KIT) as MeshLibrary).duplicate(true)
	for item in kit.get_item_list():
		var mesh := kit.get_item_mesh(item)
		if mesh == null:
			continue
		mesh = mesh.duplicate()
		var floor := kit.get_item_name(item).begins_with("Piso")
		for surface in mesh.get_surface_count():
			var material := mesh.surface_get_material(surface)
			mesh.surface_set_material(surface, _floor(material) if floor else _glossy(material))
		kit.set_item_mesh(item, mesh)
	var shapes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SHAPES))
	var ids := {}
	var previous := _out_kit if ResourceLoader.exists(_out_kit) else OUT_KIT
	if ResourceLoader.exists(previous):
		var old: MeshLibrary = ResourceLoader.load(previous, "", ResourceLoader.CACHE_MODE_IGNORE)
		for item in old.get_item_list():
			ids[old.get_item_name(item)] = item
			for kind: String in KINDS:
				var code := old.get_item_name(item).trim_prefix(KINDS[kind][0])
				if old.get_item_name(item).begins_with(KINDS[kind][0]) and code not in shapes.get(kind, []):
					shapes[kind] = shapes.get(kind, []) + [code]
	var next := maxi(kit.get_last_unused_item_id(), (ids.values().max() + 1) if ids else 0)
	for kind: String in KINDS:
		var source := kit.find_item_by_name(KINDS[kind][1])
		for code: String in shapes.get(kind, []):
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			var path: String = _walls % [kind, code]
			var mesh: Mesh = load(path if ResourceLoader.exists(path) else MESHES % [kind, code])
			for surface in mesh.get_surface_count():
				tool.append_from(mesh, surface, Transform3D.IDENTITY)
			tool.set_material(_wood())
			var item_name: String = KINDS[kind][0] + code
			var id: int = ids.get(item_name, next)
			if id == next:
				next += 1
			kit.create_item(id)
			kit.set_item_name(id, item_name)
			kit.set_item_mesh(id, tool.commit())
			kit.set_item_shapes(id, kit.get_item_shapes(source))
			kit.set_item_navigation_mesh(id, kit.get_item_navigation_mesh(source))
	var window := ShaderMaterial.new()
	window.shader = WINDOW
	window.render_priority = -1
	var fog := ShaderMaterial.new()
	fog.shader = PIT_FOG
	var dark_fog := fog.duplicate() as ShaderMaterial
	dark_fog.set_shader_parameter("fog_color", Color.BLACK)
	var black := StandardMaterial3D.new()
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	black.albedo_color = Color.BLACK
	for item in kit.get_item_list():
		var hole := kit.get_item_name(item)
		if not hole.begins_with("Hueco") or hole.begins_with(DROP_PREFIX) or kit.get_item_mesh(item) == null:
			continue
		var pit := kit.get_item_mesh(item)
		kit.set_item_mesh(item, _with_window(pit, black, fog))
		var item_name := DROP_PREFIX + hole.trim_prefix("Hueco")
		var id: int = ids.get(item_name, next)
		if id == next:
			next += 1
		kit.create_item(id)
		kit.set_item_name(id, item_name)
		kit.set_item_mesh(id, _with_window(pit, window, dark_fog))
		kit.set_item_shapes(id, kit.get_item_shapes(item))
		kit.set_item_navigation_mesh(id, kit.get_item_navigation_mesh(item))
	CAPS.apply(kit, _wall_prefixes(), _caps_path(_out_kit))
	LODS.apply(kit, _wall_prefixes())
	_save_kit(kit, _out_kit)
	return ResourceLoader.load(_out_kit, "", ResourceLoader.CACHE_MODE_REPLACE)


func _save_kit(kit: MeshLibrary, path: String) -> void:
	COMPRESS.apply(kit)
	var uid := ResourceLoader.get_resource_uid(path) if ResourceLoader.exists(path) else ResourceUID.INVALID_ID
	ResourceSaver.save(kit, path)
	ResourceSaver.set_uid(path, uid if uid != ResourceUID.INVALID_ID else ResourceUID.create_id())
	_pin_ext_uids(path)


func _wall_prefixes() -> Array:
	return KINDS.values().map(func(kind: Array) -> String: return kind[0])


func _caps_path(kit_path: String) -> String:
	return kit_path.get_basename() + "_tapas.res"


## Sin el editor, el saver deja los ext_resource sin uid y el editor después reescribe el archivo.
func _pin_ext_uids(path: String) -> void:
	var text := FileAccess.get_file_as_string(path)
	var pattern := RegEx.create_from_string('\\[ext_resource type="([^"]+)" path="([^"]+)"')
	for m in pattern.search_all(text):
		var id := ResourceLoader.get_resource_uid(m.get_string(2))
		if id == ResourceUID.INVALID_ID and m.get_string(2).get_extension() in ["tres", "tscn"]:
			var header := RegEx.create_from_string('uid="(uid://[a-z0-9]+)"').search(FileAccess.open(m.get_string(2), FileAccess.READ).get_line())
			id = ResourceUID.text_to_id(header.get_string(1)) if header else id
		if id != ResourceUID.INVALID_ID:
			text = text.replace(m.get_string(), '[ext_resource type="%s" uid="%s" path="%s"' % [m.get_string(1), ResourceUID.id_to_text(id), m.get_string(2)])
	FileAccess.open(path, FileAccess.WRITE).store_string(text)


## La pieza de hueco con el fondo (lo que está más abajo que HOLE_BOTTOM) pasado a `bottom_material`; con `fog`, una copia de
## las paredes corrida hacia adentro lleva la niebla del foso.
func _with_window(mesh: Mesh, bottom_material: Material, fog: Material = null) -> ArrayMesh:
	var walls := SurfaceTool.new()
	walls.begin(Mesh.PRIMITIVE_TRIANGLES)
	var shell := SurfaceTool.new()
	shell.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bottom := SurfaceTool.new()
	bottom.begin(Mesh.PRIMITIVE_TRIANGLES)
	var material: Material = null
	for surface in mesh.get_surface_count():
		material = mesh.surface_get_material(surface)
		var data := MeshDataTool.new()
		data.create_from_surface(mesh as ArrayMesh, surface)
		for face in data.get_face_count():
			var low := true
			for k in 3:
				low = low and data.get_vertex(data.get_face_vertex(face, k)).y < HOLE_BOTTOM
			var tool := bottom if low else walls
			var inner := not low and data.get_vertex(data.get_face_vertex(face, 0)).y < 0.0 and absf(data.get_face_normal(face).y) < 0.5
			for k in 3:
				var v := data.get_face_vertex(face, k)
				tool.set_normal(data.get_vertex_normal(v))
				tool.set_uv(data.get_vertex_uv(v))
				tool.set_color(data.get_vertex_color(v))
				tool.add_vertex(data.get_vertex(v))
				if inner:
					shell.set_normal(data.get_vertex_normal(v))
					shell.add_vertex(data.get_vertex(v) + data.get_face_normal(face) * PIT_FOG_INSET)
	var out := ArrayMesh.new()
	walls.set_material(material)
	walls.commit(out)
	bottom.set_material(bottom_material)
	bottom.commit(out)
	if fog:
		shell.set_material(fog)
		shell.commit(out)
	return out


## Los huecos que caen al piso de abajo usan la pieza con ventana; los demás (fosos), la de siempre.
func _drops(level: Node, kit: MeshLibrary) -> void:
	var old := {}
	for look: Node3D in level.find_children("*", "Node3D", true, false).filter(func(n: Node) -> bool: return n.scene_file_path == DROP_LOOK.resource_path and n.name.begins_with("CaidaLA")):
		old[[look.get_parent(), look.position.snappedf(0.01)]] = look
	for floor in DropHoles.floors(level):
		var drops := {}
		var floor_y := 0.0
		for at in DropHoles.of_floor(level, floor):
			drops[Vector2(at.x, at.z).snapped(Vector2(0.01, 0.01))] = true
			floor_y = at.y
		var shafts: Array[Vector2] = []
		var cells: Array = drops.keys()
		cells.sort()
		for at: Vector2 in cells:
			if shafts.all(func(other: Vector2) -> bool: return other.distance_to(at) >= SHAFT_SPACING):
				shafts.append(at)
		for at in shafts:
			var position := DropHoles.transform_of(floor).affine_inverse() * Vector3(at.x, floor_y, at.y)
			if old.erase([floor, position.snappedf(0.01)]):
				continue
			var look := DROP_LOOK.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
			look.name = "CaidaLA%d" % floor.get_child_count()
			floor.add_child(look, true)
			look.owner = level
			look.position = position
		for grid: GridMap in floor.find_children("*", "GridMap", true, false):
			for at_cell in grid.get_used_cells():
				var hole := kit.get_item_name(grid.get_cell_item(at_cell))
				if not hole.begins_with("Hueco"):
					continue
				var at := DropHoles.transform_of(grid) * grid.map_to_local(at_cell)
				var base := "Hueco" + hole.trim_prefix(DROP_PREFIX) if hole.begins_with(DROP_PREFIX) else hole
				var want := DROP_PREFIX + base.trim_prefix("Hueco") if drops.has(Vector2(at.x, at.z).snapped(Vector2(0.01, 0.01))) else base
				grid.set_cell_item(at_cell, kit.find_item_by_name(want), grid.get_cell_item_orientation(at_cell))
	for look: Node in old.values():
		look.get_parent().remove_child(look)
		look.free()


## Duplica cada línea de pared entre salas (y la del borde), para que cada sala tenga su propia pared de 2 m: corre las celdas
## y los nodos. Lo que está sobre una línea (puertas) queda en el medio de la pared doble; las escaleras, del lado de su sala.
func _spread(level: Node) -> void:
	var covered := [{}, {}]
	var rooms := 0
	for room: Node in level.find_children("*", "Area3D", true, false):
		var shape := room.get_node_or_null(^"CollisionShape3D") as CollisionShape3D
		if not "map_cell" in room or shape == null or not shape.shape is BoxShape3D:
			continue
		rooms += 1
		var size := (shape.shape as BoxShape3D).size
		var center: Vector3 = (room as Node3D).position + shape.position
		for axis in 2:
			var c := center.x if axis == 0 else center.z
			var half := (size.x if axis == 0 else size.z) / 2.0
			for cell in range(ceili((c - half + 1.0) / 2.0 - 0.01), floori((c + half - 1.0) / 2.0 + 0.01) + 1):
				covered[axis][cell] = true
	if rooms < 2:
		return
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
	for node: Node in level.get_children():
		if node is Node3D and not node is Camera3D and not node is Light3D and not node is NavigationRegion3D and not node.get_children().any(func(n: Node) -> bool: return n is GridMap):
			(node as Node3D).position.x = 2.0 * _shift(seps[0], (node as Node3D).position.x / 2.0, 0.0)
			(node as Node3D).position.z = 2.0 * _shift(seps[1], (node as Node3D).position.z / 2.0, 0.0)
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
				var cell := grid.local_to_map(grid.transform.affine_inverse() * spot.position)
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
