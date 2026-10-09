extends SceneTree
## Renderiza los íconos de los ítems desde sus modelos 3D (PNG con fondo transparente y contorno oscuro).
## Necesita ventana (no --headless): godot --path . --script res://tools/render_item_icons.gd
## Los ítems sin modelo (mapa, brújula, contenedor de corazón) siguen con su SVG.

const OUTPUT := "res://assets/ui/items/%s.png"
const SIZE := 256
const SUPERSAMPLE := 2
const OUTLINE := Color("0b0d10")
const OUTLINE_WIDTH := 6
const PADDING := 0.04
const VIEW := Vector3(-28.0, 35.0, 0.0)
const ADVENTURE := "res://assets/kaykit_adventure/Assets/gltf/%s.gltf"
const DUNGEON := "res://assets/kaykit_dungeon_remastered/%s.glb"
const GOLD := Color(1.0, 0.78, 0.3)

## id: [modelo, rotación en grados (antes de la vista), tinte opcional]
const ICONS := {
	"sword_basic": ["res://assets/items/sword/sword_1h.tscn", Vector3(0, 0, -45)],
	"shield_wood": ["res://assets/items/shield/shield_round.tscn", Vector3(0, 0, 0)],
	"shield_mirror": ["res://assets/items/shield/shield_mirror.tscn", Vector3(0, 0, 0)],
	"bow": [ADVENTURE % "bow_withString", Vector3(0, 0, -45)],
	"arrow": [ADVENTURE % "arrow_bow_bundle", Vector3(0, 0, -45)],
	"quiver_big": [ADVENTURE % "quiver", Vector3(0, 0, -20)],
	"bomb": [ADVENTURE % "smokebomb", Vector3(0, 0, 0)],
	"bomb_bag": [ADVENTURE % "smokebomb", Vector3(0, 0, 0)],
	"small_key": [DUNGEON % "key", Vector3(0, 0, -45)],
	"boss_key": [DUNGEON % "key", Vector3(0, 0, -45), GOLD],
	"potion": [DUNGEON % "bottle_A_labeled_green", Vector3(0, 0, 0)],
	"bottle_empty": [DUNGEON % "bottle_B_brown", Vector3(0, 0, 0)],
	"tunic": ["res://assets/kaykit_adventure/Characters/gltf/Knight.glb", Vector3(0, 0, 0)],
	"armor_chainmail": ["res://assets/kaykit_adventure/Characters/gltf/Knight.glb", Vector3(0, 0, 0)],
}
## Modelos que acompañan al principal: [[modelo, posición, rotación en grados], ...].
const EXTRAS := {
	"bomb_bag": [
		[ADVENTURE % "smokebomb", Vector3(0.4, 0.0, 0.05), Vector3(0, -30, -8)],
		[ADVENTURE % "smokebomb", Vector3(0.2, 0.36, -0.12), Vector3(0, 20, 6)],
	],
}
## De los personajes, solo el torso.
const BODY_ONLY := ["tunic", "armor_chainmail"]


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
	for id: String in ICONS:
		var entry: Array = ICONS[id]
		var pivot := Node3D.new()
		viewport.add_child(pivot)
		var model: Node3D = (load(entry[0]) as PackedScene).instantiate()
		pivot.add_child(model)
		if id in BODY_ONLY:
			_keep_body(model)
		if entry.size() > 2:
			_tint(model, entry[2])
		var item = load("res://data/items/%s.tres" % id)
		if item.body_material:
			for mesh: MeshInstance3D in _meshes(model):
				mesh.material_override = item.body_material
		model.rotation_degrees = entry[1]
		for extra: Array in EXTRAS.get(id, []):
			var companion: Node3D = (load(extra[0]) as PackedScene).instantiate()
			pivot.add_child(companion)
			companion.position = extra[1]
			companion.rotation_degrees = extra[2]
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


func _meshes(node: Node) -> Array:
	return node.find_children("*", "MeshInstance3D", true, false)


func _keep_body(model: Node) -> void:
	for mesh: MeshInstance3D in _meshes(model):
		if not mesh.name.ends_with("Body"):
			mesh.visible = false
		else:
			mesh.skeleton = NodePath()
			mesh.skin = null


func _tint(model: Node, color: Color) -> void:
	for mesh: MeshInstance3D in _meshes(model):
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(surface)
			if material is StandardMaterial3D:
				var tinted := material.duplicate() as StandardMaterial3D
				tinted.albedo_color = color
				tinted.metallic = 0.6
				tinted.roughness = 0.35
				mesh.set_surface_override_material(surface, tinted)


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
