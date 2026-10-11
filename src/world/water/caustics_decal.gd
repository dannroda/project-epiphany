class_name CausticsDecal
extends Decal
## Decal de una WaterPool que derrama el agua en el piso de alrededor: como proyecta hacia abajo y normal_fade descarta
## lo vertical, no se encima con el reflejo de las paredes. Dibuja el mismo patrón en coordenadas de mundo.

@export var caustics_material: ShaderMaterial
@export_range(64, 1024, 64) var resolution := 256

var canvas: CausticsCanvas


func _ready() -> void:
	canvas = CausticsCanvas.new(caustics_material, resolution)
	texture_emission = canvas.texture


func draw(water: ShaderMaterial, surface_y: float, pool_min: Vector2, pool_max: Vector2) -> void:
	var extent := Vector2(size.x, size.z)
	canvas.draw(water, surface_y, pool_min, pool_max, {
		&"planar": true,
		&"plane_origin": Vector2(global_position.x, global_position.z) - extent * 0.5,
		&"plane_size": extent,
	})
