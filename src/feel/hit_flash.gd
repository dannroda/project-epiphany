class_name HitFlash
extends Node
## Flash blanco en las mallas de una entidad cuando su Health recibe daño.

const SHADER := preload("res://src/feel/hit_flash.gdshader")

@export var health: Health
## Sus mallas destellan; las que se ponen después se suman con `cover`.
@export var visuals: Node3D

var _material := ShaderMaterial.new()
var _tween: Tween


func _ready() -> void:
	_material.shader = SHADER
	_material.set_shader_parameter(&"color", Feel.settings.flash_color)
	if visuals:
		cover(visuals)
	if health:
		health.damaged.connect(func(_amount: int) -> void: play())


## Suma las mallas de `node` (equipo que se pone después): destellan y marcan el stencil como el cuerpo, así la
## silueta no se dibuja sobre su propio escudo.
func cover(node: Node) -> void:
	for mesh in node.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).material_overlay = _material


## Otra pasada para todas sus mallas (la silueta del player detrás de las paredes). Va con más prioridad para
## dibujarse después del destello de todas las mallas, que marca el stencil.
func add_pass(material: Material) -> void:
	material.render_priority = _material.render_priority + 1
	_material.next_pass = material


func play() -> void:
	if not Feel.settings.flash_enabled:
		return
	if _tween and _tween.is_valid():
		_tween.kill()
	_material.set_shader_parameter(&"color", Feel.settings.flash_color)
	_set_flash(1.0)
	_tween = create_tween()
	_tween.tween_method(_set_flash, 1.0, 0.0, Feel.settings.flash_time)


## Brillo que crece mientras un enemigo carga el golpe y se apaga al soltarlo.
func warn(duration: float) -> void:
	if not Feel.settings.flash_enabled:
		return
	if _tween and _tween.is_valid():
		_tween.kill()
	_material.set_shader_parameter(&"color", Feel.settings.warn_color)
	var strength := Feel.settings.warn_strength
	_tween = create_tween()
	_tween.tween_method(_set_flash, 0.0, strength, duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_tween.tween_method(_set_flash, strength, 0.0, 0.12)


func flash_amount() -> float:
	return _material.get_shader_parameter(&"flash")


func _set_flash(value: float) -> void:
	_material.set_shader_parameter(&"flash", value)
