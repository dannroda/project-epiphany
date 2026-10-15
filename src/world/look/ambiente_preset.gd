@tool
class_name AmbientePreset
extends Resource
## Cámara, viñeta (TonoLA) y luz de una sala, para compartir entre salas del mismo tamaño o para un acercamiento.
## Cada grupo se usa solo si está tildado; lo que no, queda como el del nivel.

const TONE := preload("res://src/world/look/tono_la.gd")
const TONE_PROPERTIES := ["exposure", "vignette", "frame", "frame_softness", "frame_slant", "frame_sides", "frame_top", "frame_bottom"]
const LIGHT_PROPERTIES := ["ambient_light_color", "ambient_light_energy"]

@export_group("Cámara")
@export var usar_camara := true
## Como el `offset` de la TopDownCamera.
@export var offset := Vector3(0, 34.44, 16.06)
## Como el `field_of_view` de la TopDownCamera.
@export var fov := 28.0

@export_group("Viñeta")
@export var usar_vineta := true
@export var exposure := 1.0
@export var vignette := 1.0
@export var frame := 0.1
@export var frame_softness := 0.8
@export var frame_slant := 0.15
@export var frame_sides := 0.0
@export var frame_top := 0.0
@export var frame_bottom := 0.0

@export_group("Luz")
@export var usar_luz := false
@export var ambient_light_color := Color(0.55, 0.55, 0.65)
@export var ambient_light_energy := 1.0


## Lo tildado, como objeto → {propiedad: valor} (el TonoLA y el Environment de world).
func targets(world: WorldEnvironment) -> Dictionary:
	var out := {}
	if world == null:
		return out
	var tone := tone_of(world)
	if usar_vineta and tone:
		out[tone] = _values(TONE_PROPERTIES)
	if usar_luz and world.environment:
		out[world.environment] = _values(LIGHT_PROPERTIES)
	return out


## Copia de la cámara y del WorldEnvironment los valores de los grupos tildados.
func capture(camera: Camera3D, world: WorldEnvironment) -> void:
	if usar_camara and camera:
		offset = camera.get(&"offset")
		fov = camera.get(&"field_of_view")
	for target: Object in targets(world):
		for property: String in targets(world)[target]:
			set(property, target.get(property))
	emit_changed()


static func tone_of(world: WorldEnvironment) -> CompositorEffect:
	for effect in world.compositor.compositor_effects if world and world.compositor else []:
		if effect and effect.get_script() == TONE:
			return effect
	return null


func _values(properties: Array) -> Dictionary:
	var out := {}
	for property: String in properties:
		out[property] = get(property)
	return out
