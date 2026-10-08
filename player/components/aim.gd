class_name Aim
extends Node
## Una sola dirección de apuntado: objetivo fijado > stick derecho > stick izquierdo al tensar > mouse > hacia donde mira.

enum Source { FACING, STICK, MOUSE, TARGET, MOVE_STICK }

@export var player: PlayerCharacter
@export var stick_deadzone := 0.3
## Distancia de la retícula cuando no apunta el mouse.
@export var reticle_distance := 4.0
@export var turn_speed := 14.0

## Lo prenden los ítems a distancia: el modelo gira hacia la dirección de apuntado.
var aiming := false:
	set(value):
		if value and not aiming:
			_held = _flat(player.model.global_basis.z)
		aiming = value
## Al tensar (arco) el player se planta y el stick izquierdo apunta, como en Ocarina of Time.
var move_aims := false
## Ángulo (radianes) entre el frente del modelo y hacia donde apunta la animación (el arco de KayKit tensa de costado).
var yaw_offset := 0.0
var source: Source = Source.FACING

var _input_source: Source = Source.FACING
## Apuntando sin entrada, la mira queda en la última dirección (el modelo gira con yaw_offset y no puede ser la referencia).
var _held := Vector3.ZERO
var _reticle: MeshInstance3D
var _arrow: MeshInstance3D


func _ready() -> void:
	_reticle = _make_reticle()
	_arrow = _make_arrow()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_input_source = Source.MOUSE
	elif event is InputEventJoypadMotion and _stick().length() > stick_deadzone:
		_input_source = Source.STICK


func get_direction() -> Vector3:
	var target := player.targeting.current
	if target:
		source = Source.TARGET
		return _flat(target.global_position - player.global_position)
	var stick := _stick()
	if _input_source == Source.STICK and stick.length() > stick_deadzone:
		source = Source.STICK
		return Vector3(stick.x, 0.0, stick.y).normalized()
	if move_aims:
		var move := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_backward")
		if move.length() > stick_deadzone:
			source = Source.MOVE_STICK
			return Vector3(move.x, 0.0, move.y).normalized()
	match _input_source:
		Source.MOUSE:
			var hit = mouse_on_ground()
			if hit != null:
				var dir := _flat(hit - player.global_position)
				if not dir.is_zero_approx():
					source = Source.MOUSE
					return dir
	source = Source.FACING
	if aiming and not _held.is_zero_approx():
		return _held
	return _flat(player.model.global_basis.z)


## Punto del suelo bajo el mouse (plano a la altura del player + 1), o null.
func mouse_on_ground(screen_point: Variant = null) -> Variant:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return null
	var mouse: Vector2 = screen_point if screen_point != null else get_viewport().get_mouse_position()
	var ground := Plane(Vector3.UP, player.global_position.y + 1.0)
	return ground.intersects_ray(camera.project_ray_origin(mouse), camera.project_ray_normal(mouse))


func _physics_process(delta: float) -> void:
	var direction := get_direction()
	if aiming and not direction.is_zero_approx():
		_held = direction
		var facing := direction.rotated(Vector3.UP, -yaw_offset)
		var desired := player.model.global_transform.looking_at(player.model.global_position - facing, Vector3.UP).basis
		player.model.global_basis = player.model.global_basis.slerp(desired, clampf(turn_speed * delta, 0.0, 1.0)).orthonormalized()
	_update_debug(direction)


func _update_debug(direction: Vector3) -> void:
	var debug := DebugOverlay.visible
	_reticle.visible = aiming or debug
	_arrow.visible = debug
	if _reticle.visible:
		var point = mouse_on_ground() if source == Source.MOUSE else null
		var at: Vector3 = point if point != null else player.global_position + direction * reticle_distance
		_reticle.global_position = Vector3(at.x, player.global_position.y + 0.05, at.z)
	if debug:
		_arrow.global_position = player.global_position + Vector3.UP * 0.1
		if not direction.is_zero_approx():
			_arrow.look_at(_arrow.global_position + direction, Vector3.UP)
		DebugOverlay.watch("aim/source", Source.find_key(source))
		DebugOverlay.watch("aim/direction", direction.snappedf(0.01))


func _stick() -> Vector2:
	return Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down")


func _flat(v: Vector3) -> Vector3:
	v.y = 0.0
	return v.normalized()


func _make_reticle() -> MeshInstance3D:
	var ring := TorusMesh.new()
	ring.inner_radius = 0.28
	ring.outer_radius = 0.36
	ring.rings = 24
	return _floor_mesh(ring, Color(1.0, 0.85, 0.4, 0.8))


## Franja con punta hacia -Z (look_at apunta -Z a la dirección).
func _make_arrow() -> MeshInstance3D:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for v in [Vector3(-0.04, 0, 0), Vector3(0.04, 0, 0), Vector3(0.04, 0, -1.7),
			Vector3(-0.04, 0, 0), Vector3(0.04, 0, -1.7), Vector3(-0.04, 0, -1.7),
			Vector3(-0.15, 0, -1.7), Vector3(0.15, 0, -1.7), Vector3(0, 0, -2.0)]:
		mesh.surface_add_vertex(v)
	mesh.surface_end()
	return _floor_mesh(mesh, Color(0.4, 0.8, 1.0, 0.8))


func _floor_mesh(mesh: Mesh, color: Color) -> MeshInstance3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.no_depth_test = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.top_level = true
	instance.visible = false
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	player.add_child.call_deferred(instance)
	return instance
