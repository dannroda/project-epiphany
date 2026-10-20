class_name Aim
extends Node
## Una sola dirección de apuntado: objetivo fijado > stick izquierdo al tensar > mouse > hacia donde mira.
## El stick derecho no apunta: mueve la cámara (TopDownCamera). El mouse solo apunta si lo último fue teclado y mouse.

enum Source { FACING, MOUSE, TARGET, MOVE_STICK }

@export var player: PlayerCharacter
@export var stick_deadzone := 0.3
## Distancia de la retícula cuando no apunta el mouse.
@export var reticle_distance := 4.0
@export var turn_speed := 14.0
## Distancia de lanzamiento apuntando con el stick (sin objetivo ni mouse).
@export var throw_distance := 6.0
## Con el mouse más cerca que esto del player, se coloca en vez de lanzar.
@export var min_mouse_throw := 1.5

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

## Apuntando sin entrada, la mira queda en la última dirección (el modelo gira con yaw_offset y no puede ser la referencia).
var _held := Vector3.ZERO
@onready var _reticle: MeshInstance3D = %Reticle
@onready var _arrow: MeshInstance3D = %AimArrow


func _ready() -> void:
	_arrow.mesh = _arrow_mesh()


## Se movió el mouse después del último uso del gamepad.
var _mouse_moved := false


func _input(event: InputEvent) -> void:
	if not player.controls.owns(event):
		return
	if event is InputEventMouseMotion:
		_mouse_moved = true
	elif event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > stick_deadzone):
		_mouse_moved = false


func mouse_aims() -> bool:
	return _mouse_moved and Settings.get_value(&"mouse_aim")


func get_direction() -> Vector3:
	var target := player.targeting.current
	if target:
		source = Source.TARGET
		return _flat(target.global_position - player.global_position)
	if move_aims:
		var move := player.controls.move()
		if move.length() > stick_deadzone:
			source = Source.MOVE_STICK
			return Vector3(move.x, 0.0, move.y).normalized()
	if mouse_aims():
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


## Hacia dónde lanzar si se está apuntando (objetivo, stick al tensar, mouse lejos); null = colocar.
func throw_point() -> Variant:
	var direction := get_direction()
	match source:
		Source.TARGET:
			return player.targeting.current.global_position
		Source.MOVE_STICK:
			return player.global_position + direction * throw_distance
		Source.MOUSE:
			var hit = mouse_on_ground()
			var ground := Vector3(hit.x, player.global_position.y, hit.z) if hit != null else player.global_position
			if ground.distance_to(player.global_position) >= min_mouse_throw:
				return ground
	return null


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
		var from := player.model.global_basis.orthonormalized()
		player.model.global_basis = from.slerp(desired.orthonormalized(), clampf(turn_speed * Settings.stick_factor() * delta, 0.0, 1.0)).orthonormalized()
	_update_debug(direction)


func _update_debug(direction: Vector3) -> void:
	var debug: bool = DebugOverlay.visible
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


## Lo que apunta el jugador a propósito: el mouse, o el stick derecho (solo para girar el reflejo del escudo espejo; el
## resto del tiempo mueve la cámara). Cero si no está apuntando (no cae en el frente del modelo).
func pointed_direction() -> Vector3:
	var stick := player.controls.look()
	if stick.length() > stick_deadzone:
		return Vector3(stick.x, 0.0, stick.y).normalized()
	if mouse_aims():
		var hit = mouse_on_ground()
		if hit != null:
			return _flat(hit - player.global_position)
	return Vector3.ZERO


func _flat(v: Vector3) -> Vector3:
	v.y = 0.0
	return v.normalized()


## Franja con punta hacia -Z (look_at apunta -Z a la dirección).
func _arrow_mesh() -> Mesh:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for v in [Vector3(-0.04, 0, 0), Vector3(0.04, 0, 0), Vector3(0.04, 0, -1.7),
			Vector3(-0.04, 0, 0), Vector3(0.04, 0, -1.7), Vector3(-0.04, 0, -1.7),
			Vector3(-0.15, 0, -1.7), Vector3(0.15, 0, -1.7), Vector3(0, 0, -2.0)]:
		mesh.surface_add_vertex(v)
	mesh.surface_end()
	return mesh
