class_name ZoneVeil
extends MeshInstance3D
## Tapa su AreaZone (el padre) mientras nunca se estuvo ahí y lo que la cierra sigue entero.
## Cuando uno de sus bloqueos se abre, se disuelve desde ahí sin frenar el juego.
## Llega hasta la cara de afuera de las paredes que la rodean (`wall_margin`) y a la altura de su tapa
## (`top`), así del otro lado no se ve nada (11.54).

## CrackedWall o Gate que cierran la zona.
@export var blockers: Array[NodePath] = []
## Grosor de la pared que rodea la zona (una celda del GridMap).
@export var wall_margin := 1.95
## Franja donde el borde de la niebla se deshace en jirones: `fringe_out` por fuera de la pared, el resto por dentro.
@export var fringe := 3.0
@export var fringe_out := 1.0
## A ras de la tapa de las paredes (2,6 m): más alto, la cara del velo asoma por encima del muro.
@export var top := 2.62
@export var bottom := -1.0
@export var reveal_time := 1.2

var _zone: AreaZone
var _rect: Rect2
var _cover: Rect2
var _center := Vector2.ZERO
var _radius := 0.0
var _tween: Tween


func _ready() -> void:
	add_to_group(&"zone_veils")
	_zone = get_parent() as AreaZone
	_cover = _zone.bounds().grow(wall_margin)
	_rect = _cover.grow(fringe_out)
	set_instance_shader_parameter(&"fringe", fringe)
	set_instance_shader_parameter(&"rect", Vector4(_rect.position.x, _rect.position.y, _rect.end.x, _rect.end.y))
	global_transform = Transform3D(Basis.from_scale(Vector3(_rect.size.x, top - bottom, _rect.size.y)),
		Vector3(_rect.get_center().x, (top + bottom) / 2.0, _rect.get_center().y))
	for path in blockers:
		var blocker := get_node(path)
		for signal_name: StringName in [&"broken", &"opened"]:
			if blocker.has_signal(signal_name):
				blocker.connect(signal_name, _open.bind(blocker))
	_zone.body_entered.connect(func(body: Node3D) -> void:
		if body is PlayerCharacter and not is_revealing():
			hide())
	GameState.loaded.connect(_refresh, CONNECT_DEFERRED)
	_refresh.call_deferred()


## Si el punto (XZ del mundo) sigue tapado.
func covers(point: Vector2) -> bool:
	return visible and _cover.has_point(point) and point.distance_to(_center) >= _radius


func is_revealing() -> bool:
	return _tween != null and _tween.is_running()


func _refresh() -> void:
	if _tween:
		_tween.kill()
	_set_radius(0.0)
	visible = not _zone.is_visited() and not blockers.any(func(path: NodePath) -> bool:
		var blocker := get_node(path)
		return blocker.get(&"is_broken") == true or blocker.get(&"is_open") == true)


func _open(blocker: Node3D) -> void:
	if not visible or is_revealing():
		return
	_center = Vector2(blocker.global_position.x, blocker.global_position.z)
	var far := 0.0
	for corner in [_rect.position, _rect.end, Vector2(_rect.position.x, _rect.end.y), Vector2(_rect.end.x, _rect.position.y)]:
		far = maxf(far, _center.distance_to(corner))
	_tween = create_tween()
	_tween.tween_method(_set_radius, 0.0, far + 2.0, reveal_time).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_tween.tween_callback(hide)


func _set_radius(radius: float) -> void:
	_radius = radius
	set_instance_shader_parameter(&"reveal_center", _center)
	set_instance_shader_parameter(&"reveal_radius", radius)
