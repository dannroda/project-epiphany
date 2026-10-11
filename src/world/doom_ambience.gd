class_name DoomAmbience
extends Node
## El despertar del ojo, sala a sala: según el `Room.doom` de la sala actual (suavizado), la luz vira a rojo,
## sube la niebla, cae polvo, aparecen grietas en el piso y el templo tiembla cada vez más seguido.
## El player y los objetos con los que se interactúa quedan sin teñir: van en su propia capa visual, que el sol rojo
## no ilumina (sí proyectan sombra), los ilumina una luz neutra con la misma dirección y no les llega la niebla.

## Capa visual (bit) de lo que se tiene que leer con cualquier doom.
const LEGIBLE_LAYER := 2

@export var calm_ambient := Color(0.55, 0.52, 0.65)
@export var doom_ambient := Color(0.8, 0.3, 0.25)
@export var calm_sun := Color(1, 1, 1)
@export var doom_sun := Color(1.0, 0.45, 0.35)
@export var fog_color := Color(0.25, 0.08, 0.06)
@export var max_fog_density := 0.035
## Cuánto tarda en llegar al doom de la sala nueva (por segundo).
@export var blend_speed := 0.5
## Segundos entre temblores en la calma y en el clímax.
@export var tremor_interval := Vector2(14.0, 4.0)
@export var seed_value := 7

## Doom aplicado ahora (0..1).
var level := 0.0
var environment: Environment
var sun: DirectionalLight3D
var dust: GPUParticles3D
var cracks: Array[Decal] = []
var legible_light: DirectionalLight3D
var legible: Array[GeometryInstance3D] = []
var _next_tremor := 6.0
var _fogless := {}
var _recheck := 0.0


func _ready() -> void:
	var scene := get_parent()
	for child in scene.get_children():
		if child is WorldEnvironment:
			environment = (child as WorldEnvironment).environment
		elif child is DirectionalLight3D:
			sun = child
	_make_dust.call_deferred()
	_make_cracks.call_deferred()
	if sun:
		sun.light_cull_mask &= ~LEGIBLE_LAYER
		legible_light = DirectionalLight3D.new()
		legible_light.name = "LegibleLight"
		legible_light.light_cull_mask = LEGIBLE_LAYER
		legible_light.light_energy = sun.light_energy
		legible_light.light_color = calm_sun
		legible_light.transform = sun.transform
		scene.add_child.call_deferred(legible_light)
	get_tree().node_added.connect(_on_node_added)
	_mark_tree.call_deferred(scene)


static func is_legible(node: Node) -> bool:
	return node is PlayerCharacter or node is Chest or node is Pickup or node is Breakable or node is PushBlock \
		or node is Bomb or node is Tablet or node is EyeSwitch or node is FloorSwitch


func current_doom() -> float:
	var camera := get_tree().get_first_node_in_group(&"room_camera") as TopDownCamera
	return camera.room.doom if camera and camera.room else 0.0


func _process(delta: float) -> void:
	level = move_toward(level, current_doom(), blend_speed * delta)
	if environment:
		environment.ambient_light_color = calm_ambient.lerp(doom_ambient, level)
		environment.fog_enabled = level > 0.05
		environment.fog_density = level * max_fog_density
		environment.fog_light_color = fog_color
	if sun:
		sun.light_color = calm_sun.lerp(doom_sun, level)
	if dust:
		dust.amount_ratio = clampf(level * 1.2, 0.0, 1.0)
		var camera := get_tree().get_first_node_in_group(&"room_camera") as TopDownCamera
		if camera:
			dust.global_position = camera.focus + Vector3.UP * 4.0
	_recheck -= delta
	if _recheck <= 0.0:
		_recheck = 0.5
		_refresh_legible()
	if level > 0.3:
		_next_tremor -= delta
		if _next_tremor <= 0.0:
			tremor()


func tremor() -> void:
	_next_tremor = lerpf(tremor_interval.x, tremor_interval.y, level) * randf_range(0.7, 1.3)
	Feel.shake(0.06 + 0.14 * level)
	var player := Players.lead()
	if player:
		Feel.sfx(&"rumble", player.global_position)
		if level > 0.5 and dust:
			dust.restart()


func _make_dust() -> void:
	dust = GPUParticles3D.new()
	dust.name = "DoomDust"
	dust.amount = 120
	dust.lifetime = 4.0
	dust.amount_ratio = 0.0
	dust.visibility_aabb = AABB(Vector3(-14, -8, -10), Vector3(28, 12, 20))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(12, 0.5, 8)
	process.direction = Vector3.DOWN
	process.spread = 15.0
	process.initial_velocity_min = 0.2
	process.initial_velocity_max = 0.6
	process.gravity = Vector3(0, -0.6, 0)
	process.scale_min = 0.5
	process.scale_max = 1.2
	dust.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(0.06, 0.06)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.albedo_color = Color(0.75, 0.68, 0.6, 0.7)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	quad.material = material
	dust.draw_pass_1 = quad
	get_parent().add_child(dust)


## Grietas en el piso: más cuanto más doom tiene la sala (siempre en los mismos lugares).
func _make_cracks() -> void:
	if not is_inside_tree():
		return
	var texture := crack_texture()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for room: Room in get_tree().get_nodes_in_group(Room.GROUP):
		var bounds := room.bounds()
		for i in int(room.doom * 7.0):
			var decal := Decal.new()
			decal.texture_albedo = texture
			decal.size = Vector3(rng.randf_range(2.0, 4.0), 1.0, rng.randf_range(2.0, 4.0))
			decal.modulate = Color(0.12, 0.08, 0.08)
			decal.cull_mask &= ~LEGIBLE_LAYER
			get_parent().add_child(decal)
			decal.global_position = Vector3(rng.randf_range(bounds.position.x + 1.5, bounds.end.x - 1.5), 0.1, rng.randf_range(bounds.position.y + 1.5, bounds.end.y - 1.5))
			decal.rotation.y = rng.randf() * TAU
			cracks.append(decal)


func _on_node_added(node: Node) -> void:
	if node is GeometryInstance3D:
		_mark_if_legible.call_deferred(node)


func _mark_tree(root: Node) -> void:
	for geometry in root.find_children("*", "GeometryInstance3D", true, false):
		_mark_if_legible(geometry)


## Sin tipo: puede llegar diferido un nodo que ya se liberó.
func _mark_if_legible(maybe_geometry) -> void:
	if not is_instance_valid(maybe_geometry):
		return
	var geometry := maybe_geometry as GeometryInstance3D
	if not geometry.is_inside_tree() or legible.has(geometry):
		return
	var node: Node = geometry
	while node:
		if is_legible(node):
			geometry.layers = LEGIBLE_LAYER
			legible.append(geometry)
			_clear_fog(geometry)
			return
		node = node.get_parent()


## Lo que cambia el material después (el equipo viste al player con `material_override`) vuelve a quedar sin niebla.
func _refresh_legible() -> void:
	for i in range(legible.size() - 1, -1, -1):
		if is_instance_valid(legible[i]):
			_clear_fog(legible[i])
		else:
			legible.remove_at(i)


func _clear_fog(geometry: GeometryInstance3D) -> void:
	if geometry.material_override is BaseMaterial3D:
		geometry.material_override = _fogless_copy(geometry.material_override)
	var mesh_instance := geometry as MeshInstance3D
	if mesh_instance == null or mesh_instance.mesh == null:
		return
	for i in mesh_instance.mesh.get_surface_count():
		var material := mesh_instance.get_surface_override_material(i)
		if material == null:
			material = mesh_instance.mesh.surface_get_material(i)
		if material is BaseMaterial3D and not material.disable_fog:
			mesh_instance.set_surface_override_material(i, _fogless_copy(material))


func _fogless_copy(material: BaseMaterial3D) -> BaseMaterial3D:
	if material.disable_fog:
		return material
	if not _fogless.has(material):
		var copy := material.duplicate() as BaseMaterial3D
		copy.disable_fog = true
		_fogless[material] = copy
	return _fogless[material]


static func crack_texture() -> ImageTexture:
	var size := 128
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for branch in 5:
		var point := Vector2(size / 2.0, size / 2.0)
		var angle := TAU * branch / 5.0 + rng.randf_range(-0.4, 0.4)
		for step in 40:
			angle += rng.randf_range(-0.5, 0.5)
			point += Vector2.from_angle(angle) * 1.4
			if not Rect2(1, 1, size - 2, size - 2).has_point(point):
				break
			var width := 2 if step < 18 else 1
			for dx in width:
				for dy in width:
					image.set_pixel(int(point.x) + dx, int(point.y) + dy, Color(1, 1, 1, 1.0 - step / 45.0))
	return ImageTexture.create_from_image(image)
