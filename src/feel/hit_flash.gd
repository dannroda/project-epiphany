class_name HitFlash
extends Node
## Flash blanco en las mallas de una entidad cuando su Health recibe daño.

const SHADER := preload("res://src/feel/hit_flash.gdshader")

var _material := ShaderMaterial.new()
var _tween: Tween


static func attach(visuals: Node3D, health: Health) -> HitFlash:
	var flash := HitFlash.new()
	flash.name = "HitFlash"
	visuals.add_child(flash)
	flash._setup(visuals, health)
	return flash


func _setup(visuals: Node3D, health: Health) -> void:
	_material.shader = SHADER
	_material.set_shader_parameter(&"color", Feel.settings.flash_color)
	for mesh in visuals.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).material_overlay = _material
	health.damaged.connect(func(_amount: int) -> void: play())


func play() -> void:
	if not Feel.settings.flash_enabled:
		return
	if _tween and _tween.is_valid():
		_tween.kill()
	_material.set_shader_parameter(&"flash", 1.0)
	_tween = create_tween()
	_tween.tween_method(func(v: float) -> void: _material.set_shader_parameter(&"flash", v), 1.0, 0.0, Feel.settings.flash_time)
