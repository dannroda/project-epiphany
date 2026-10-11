@tool
class_name WaterPool
extends Node3D
## Pileta de agua: superficie (water.gdshader), fondo y paredes de piedra, un bloqueo para no meterse y una luz bajo
## el agua que proyecta su reflejo en las paredes cercanas (caustics.gdshader). El origen es el centro del borde, a ras del piso; va en
## celdas del GridMap sin piso.

const SURFACE_DROP := 0.12

## Medidas en XZ (m) y profundidad del fondo bajo el piso.
@export var size := Vector2(4.0, 4.0):
	set(value):
		size = value
		if is_node_ready():
			_build()
@export var depth := 0.9:
	set(value):
		depth = value
		if is_node_ready():
			_build()
@export var caustics_material: ShaderMaterial
@export_range(64, 1024, 64) var resolution := 256
## Segundos entre gotas (mín, máx); cero = sin goteo.
@export var drips := Vector2(1.2, 3.5)

var texture: DrawableTexture2D
var _source: ImageTexture
var _next_drip := 0.0

@onready var surface: MeshInstance3D = $Surface
@onready var basin: MeshInstance3D = $Basin
@onready var block: CollisionShape3D = $Block/CollisionShape3D
@onready var light: SpotLight3D = $Caustics


func _ready() -> void:
	_build()
	if Engine.is_editor_hint() or caustics_material == null:
		return
	caustics_material = caustics_material.duplicate()
	var water := surface.mesh.surface_get_material(0) as ShaderMaterial
	for param in [&"tile", &"speed"]:
		caustics_material.set_shader_parameter(param, water.get_shader_parameter(param))
	texture = DrawableTexture2D.new()
	texture.setup(resolution, resolution, DrawableTexture2D.DRAWABLE_FORMAT_RGBA8, Color.BLACK, false)
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	_source = ImageTexture.create_from_image(image)
	light.light_projector = texture


func _process(delta: float) -> void:
	if texture:
		_aim_caustics()
		texture.blit_rect(Rect2i(0, 0, resolution, resolution), _source, Color.WHITE, 0, caustics_material)
	if Engine.is_editor_hint() or drips.y <= 0.0:
		return
	_next_drip -= delta
	if _next_drip <= 0.0:
		_next_drip = randf_range(drips.x, drips.y)
		var spot := Vector3(randf_range(-0.5, 0.5) * size.x, -SURFACE_DROP, randf_range(-0.5, 0.5) * size.y)
		Feel.sfx(&"drip", to_global(spot))


## Le pasa a las cáusticas la pose de la luz y el plano del agua, así se puede mover y abrir la luz a ojo.
func _aim_caustics() -> void:
	var pose := light.global_transform
	caustics_material.set_shader_parameter(&"light_basis", pose.basis.orthonormalized())
	caustics_material.set_shader_parameter(&"light_origin", pose.origin)
	caustics_material.set_shader_parameter(&"tan_half_angle", tan(deg_to_rad(light.spot_angle)))
	caustics_material.set_shader_parameter(&"surface_y", surface.global_position.y)
	var center := Vector2(global_position.x, global_position.z)
	caustics_material.set_shader_parameter(&"pool_min", center - size * 0.5)
	caustics_material.set_shader_parameter(&"pool_max", center + size * 0.5)


func _build() -> void:
	var plane := surface.mesh as PlaneMesh
	plane.size = size
	surface.position.y = -SURFACE_DROP
	basin.mesh = _basin_mesh()
	(block.shape as BoxShape3D).size = Vector3(size.x, 1.4, size.y)
	block.position.y = 0.7 - depth



## Fondo y cuatro paredes que miran hacia adentro, de la superficie al fondo.
func _basin_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := Vector3(size.x / 2.0, 0.0, size.y / 2.0)
	var top := 0.0
	var bottom := -depth
	_quad(tool, Vector3(-h.x, bottom, -h.z), Vector3(h.x, bottom, -h.z), Vector3(h.x, bottom, h.z), Vector3(-h.x, bottom, h.z))
	var corners := [Vector3(-h.x, 0, -h.z), Vector3(h.x, 0, -h.z), Vector3(h.x, 0, h.z), Vector3(-h.x, 0, h.z)]
	for i in 4:
		var a: Vector3 = corners[i]
		var b: Vector3 = corners[(i + 1) % 4]
		_quad(tool, a + Vector3.UP * top, b + Vector3.UP * top, b + Vector3.UP * bottom, a + Vector3.UP * bottom)
	tool.generate_normals()
	return tool.commit()


func _quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for v in [a, b, c, a, c, d]:
		tool.add_vertex(v)
