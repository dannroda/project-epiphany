class_name CausticsLight
extends SpotLight3D
## Luz de una WaterPool bajo la superficie, mirando hacia arriba: refleja el agua en las paredes (caustics.gdshader
## sigue cada rayo del projector hasta el plano del agua). Necesita sombra: sin ella 4.8-dev7 no aplica el projector.

@export var caustics_material: ShaderMaterial
@export_range(64, 1024, 64) var resolution := 256

var canvas: CausticsCanvas


func _ready() -> void:
	canvas = CausticsCanvas.new(caustics_material, resolution)
	light_projector = canvas.texture


func draw(water: ShaderMaterial, surface_y: float, pool_min: Vector2, pool_max: Vector2) -> void:
	canvas.draw(water, surface_y, pool_min, pool_max, {
		&"light_basis": global_basis.orthonormalized(),
		&"light_origin": global_position,
		&"tan_half_angle": tan(deg_to_rad(spot_angle)),
	})
