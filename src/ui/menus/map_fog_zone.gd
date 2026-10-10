class_name MapFogZone
extends Control
## Zona del overworld sin explorar: la foto del nivel como boceto en pergamino.

const SCENE_PATH := "res://src/ui/menus/map_fog_zone.tscn"


## `uv_rect`: qué parte de `map_texture` cubre la zona.
static func create(rect: Rect2, map_texture: Texture2D, uv_rect: Rect2) -> MapFogZone:
	var fog: MapFogZone = load(SCENE_PATH).instantiate()
	fog.position = rect.position
	fog.size = rect.size
	var paper := fog.get_node(^"Paper") as ColorRect
	paper.material.set_shader_parameter(&"map_texture", map_texture)
	paper.material.set_shader_parameter(&"uv_rect", Vector4(uv_rect.position.x, uv_rect.position.y, uv_rect.size.x, uv_rect.size.y))
	return fog
