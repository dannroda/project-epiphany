extends Node
## Look de LA en los objetos: todo lo pintado con la paleta toma metal y rugosidad de palette_surface.png (metal que
## brilla, cerámica con brillo suave, tela mate). También lo que aparece después (vasijas rotas, pickups).

const PALETTE := preload("res://data/kits/materials/epiphany.tres")
const SURFACE := preload("res://assets/epiphany/palette_surface.png")

var _glossy: StandardMaterial3D


func _enter_tree() -> void:
	_glossy = PALETTE.duplicate()
	_glossy.metallic = 1.0
	_glossy.metallic_texture = SURFACE
	_glossy.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	_glossy.roughness = 1.0
	_glossy.roughness_texture = SURFACE
	_glossy.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	get_tree().node_added.connect(_apply)
	for node in get_tree().root.find_children("*", "MeshInstance3D", true, false):
		_apply(node)


func _exit_tree() -> void:
	get_tree().node_added.disconnect(_apply)


func _apply(node: Node) -> void:
	var mesh_instance := node as MeshInstance3D
	if mesh_instance == null or mesh_instance.mesh == null:
		return
	for surface in mesh_instance.mesh.get_surface_count():
		if mesh_instance.mesh.surface_get_material(surface) == PALETTE and mesh_instance.get_surface_override_material(surface) == null:
			mesh_instance.set_surface_override_material(surface, _glossy)
