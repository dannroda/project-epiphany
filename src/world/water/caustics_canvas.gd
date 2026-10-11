class_name CausticsCanvas
extends RefCounted
## La DrawableTexture2D que CausticsLight y CausticsDecal redibujan cada frame con caustics.gdshader.

var texture: DrawableTexture2D
var material: ShaderMaterial
var _source: ImageTexture
var _resolution: int


func _init(caustics_material: ShaderMaterial, resolution: int) -> void:
	material = caustics_material.duplicate()
	_resolution = resolution
	texture = DrawableTexture2D.new()
	texture.setup(resolution, resolution, DrawableTexture2D.DRAWABLE_FORMAT_RGBA8, Color.BLACK, false)
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	_source = ImageTexture.create_from_image(image)


func draw(water: ShaderMaterial, surface_y: float, pool_min: Vector2, pool_max: Vector2, params: Dictionary) -> void:
	for param in [&"tile", &"speed"]:
		material.set_shader_parameter(param, water.get_shader_parameter(param))
	material.set_shader_parameter(&"surface_y", surface_y)
	material.set_shader_parameter(&"pool_min", pool_min)
	material.set_shader_parameter(&"pool_max", pool_max)
	for param: StringName in params:
		material.set_shader_parameter(param, params[param])
	texture.blit_rect(Rect2i(0, 0, _resolution, _resolution), _source, Color.WHITE, 0, material)
