class_name CausticsLight
extends SpotLight3D
## Luz de una WaterPool: cada frame dibuja en su projector el agua vista desde la luz (caustics.gdshader). Bajo la
## superficie mirando hacia arriba refleja el agua en las paredes; arriba mirando hacia abajo la derrama en el fondo y
## el piso de alrededor (outside_reach del material). Necesita sombra: sin ella 4.8-dev7 no aplica el projector.

@export var caustics_material: ShaderMaterial
@export_range(64, 1024, 64) var resolution := 256

var texture: DrawableTexture2D
var _source: ImageTexture


func _ready() -> void:
	caustics_material = caustics_material.duplicate()
	texture = DrawableTexture2D.new()
	texture.setup(resolution, resolution, DrawableTexture2D.DRAWABLE_FORMAT_RGBA8, Color.BLACK, false)
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	_source = ImageTexture.create_from_image(image)
	light_projector = texture


func draw(water: ShaderMaterial, surface_y: float, pool_min: Vector2, pool_max: Vector2) -> void:
	for param in [&"tile", &"speed"]:
		caustics_material.set_shader_parameter(param, water.get_shader_parameter(param))
	caustics_material.set_shader_parameter(&"light_basis", global_basis.orthonormalized())
	caustics_material.set_shader_parameter(&"light_origin", global_position)
	caustics_material.set_shader_parameter(&"tan_half_angle", tan(deg_to_rad(spot_angle)))
	caustics_material.set_shader_parameter(&"surface_y", surface_y)
	caustics_material.set_shader_parameter(&"pool_min", pool_min)
	caustics_material.set_shader_parameter(&"pool_max", pool_max)
	texture.blit_rect(Rect2i(0, 0, resolution, resolution), _source, Color.WHITE, 0, caustics_material)
