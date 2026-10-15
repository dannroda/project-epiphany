extends SceneTree
## Renderiza los íconos de los ítems desde sus modelos 3D (PNG con fondo transparente y contorno oscuro).
## Necesita ventana (no --headless): godot --path . --script res://tools/render_item_icons.gd [-- id id…]

const OUTPUT := "res://assets/ui/items/%s.png"
const SIZE := 256
const SUPERSAMPLE := 2
const OUTLINE := Color("0b0d10")
const OUTLINE_WIDTH := 6
const PADDING := 0.04
const VIEW := Vector3(-28.0, 35.0, 0.0)
const MESH := "res://assets/epiphany/meshes/%s.res"
const BOTTLE := "res://assets/items/bottle/bottle.tscn"
## Las piezas planas (llaves, mapa, brújula, flechas) se paran de frente a la cámara.
const FLAT := Vector3(90, 0, 0)

## id: [modelo (escena o malla), rotación en grados (antes de la vista)]
const ICONS := {
	"sword_basic": ["res://assets/items/sword/sword_1h.tscn", Vector3(0, 0, -45)],
	"sword_golden": [MESH % "equipo/espada_dorada", Vector3(0, 0, -45)],
	"shield_wood": ["res://assets/items/shield/shield_round.tscn", Vector3(0, 0, 0)],
	"shield_mirror": ["res://assets/items/shield/shield_mirror.tscn", Vector3(0, 0, 0)],
	"bow": [MESH % "equipo/arco", Vector3(0, 0, -45)],
	"arrow": [MESH % "objetos/flechas_x5", FLAT + Vector3(0, 0, 45)],
	"quiver_big": [MESH % "equipo/carcaj", Vector3(0, 0, -20)],
	"bomb": [MESH % "objetos/bomba", Vector3(0, 0, 0)],
	"bomb_bag": [MESH % "equipo/bolsa_bombas", Vector3(0, 0, 0)],
	"small_key": [MESH % "objetos/llave", FLAT + Vector3(0, 0, 45)],
	"boss_key": [MESH % "objetos/llave_jefe", FLAT + Vector3(0, 0, 45)],
	"potion": [BOTTLE, Vector3(0, 0, 0)],
	"bottle_empty": [BOTTLE, Vector3(0, 0, 0)],
	"holy_water": [BOTTLE, Vector3(0, 0, 0)],
	"dungeon_map": [MESH % "objetos/mapa", FLAT],
	"compass": [MESH % "objetos/brujula", FLAT],
	"heart_container": [MESH % "objetos/contenedor_corazon", Vector3(0, 0, 0)],
	"heart_piece": [MESH % "objetos/pieza_corazon", Vector3(0, 0, 0)],
	"tunic": [MESH % "equipo/armadura", Vector3(0, 0, 0)],
	"armor_chainmail": [MESH % "equipo/armadura", Vector3(0, 0, 0)],
	"feather": [MESH % "equipo/pluma", Vector3(0, 0, -35)],
	"sandals": [MESH % "equipo/sandalias", Vector3(40, 0, 0)],
	"hookshot": [MESH % "equipo/gancho", Vector3(0, 0, -45)],
	"hammer": [MESH % "equipo/martillo", Vector3(0, 0, -45)],
}

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(SIZE, SIZE) * SUPERSAMPLE
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.75, 0.72, 0.68)
	environment.environment.ambient_light_energy = 0.9
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment.sky = Sky.new()
	environment.environment.sky.sky_material = ProceduralSkyMaterial.new()
	environment.environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	viewport.add_child(environment)
	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-45, -35, 0)
	key_light.light_energy = 1.1
	viewport.add_child(key_light)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 150, 0)
	rim.light_energy = 0.5
	viewport.add_child(rim)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	viewport.add_child(camera)

	var failed := false
	var only := OS.get_cmdline_user_args()
	for id: String in ICONS:
		if not only.is_empty() and not id in only:
			continue
		var entry: Array = ICONS[id]
		var pivot := Node3D.new()
		viewport.add_child(pivot)
		var model := _instance(entry[0])
		pivot.add_child(model)
		var item_path := "res://data/items/%s.tres" % id
		var item = load(item_path) if ResourceLoader.exists(item_path) else null
		if model is BottleModel:
			(model as BottleModel).content = item
		if item and item.body_material:
			for mesh: MeshInstance3D in _meshes(model):
				mesh.material_override = item.body_material
		model.rotation_degrees = entry[1]
		pivot.rotation_degrees = VIEW
		_frame(camera, pivot)
		for i in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		image.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
		_outline(image)
		var err := image.save_png(ProjectSettings.globalize_path(OUTPUT % id))
		print("%s: %s" % [id, error_string(err)])
		failed = failed or err != OK
		pivot.free()
	quit(1 if failed else 0)


func _instance(path: String) -> Node3D:
	if path.ends_with(".res"):
		var holder := Node3D.new()
		var mesh := MeshInstance3D.new()
		mesh.mesh = load(path)
		holder.add_child(mesh)
		return holder
	return (load(path) as PackedScene).instantiate()


func _meshes(node: Node) -> Array:
	return node.find_children("*", "MeshInstance3D", true, false)


## Encuadra la caja de lo visible, vista desde la cámara, con un margen.
func _frame(camera: Camera3D, pivot: Node3D) -> void:
	var points: Array[Vector3] = []
	for mesh: MeshInstance3D in _meshes(pivot):
		if not mesh.is_visible_in_tree():
			continue
		var box := mesh.get_aabb()
		for i in 8:
			points.append(mesh.global_transform * box.get_endpoint(i))
	var center := Vector3.ZERO
	for point in points:
		center += point
	center /= points.size()
	camera.global_transform = Transform3D(Basis(), center + Vector3(0, 0, 10))
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for point in points:
		var local := camera.global_transform.affine_inverse() * point
		low = low.min(Vector2(local.x, local.y))
		high = high.max(Vector2(local.x, local.y))
	var view_center := (low + high) * 0.5
	camera.global_transform.origin += camera.global_transform.basis * Vector3(view_center.x, view_center.y, 0)
	camera.size = maxf(high.x - low.x, high.y - low.y) * (1.0 + PADDING * 2.0)


## Contorno oscuro alrededor de la silueta, como los íconos planos de los mockups.
func _outline(image: Image) -> void:
	var source := image.duplicate() as Image
	var w := image.get_width()
	var h := image.get_height()
	for y in h:
		for x in w:
			if source.get_pixel(x, y).a > 0.5:
				continue
			var near := 0.0
			for dy in range(-OUTLINE_WIDTH, OUTLINE_WIDTH + 1):
				for dx in range(-OUTLINE_WIDTH, OUTLINE_WIDTH + 1):
					if dx * dx + dy * dy > OUTLINE_WIDTH * OUTLINE_WIDTH:
						continue
					var sx := x + dx
					var sy := y + dy
					if sx >= 0 and sy >= 0 and sx < w and sy < h:
						near = maxf(near, source.get_pixel(sx, sy).a)
			if near > 0.0:
				var under := source.get_pixel(x, y)
				var color := OUTLINE.lerp(under, under.a)
				color.a = maxf(near, under.a)
				image.set_pixel(x, y, color)
