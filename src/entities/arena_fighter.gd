@abstract
class_name ArenaFighter
extends Node3D
## Sub-jefe que maneja un ArenaFight (o una oleada): le da arena, ritmo, turno de ataque y compañeros.
## Las esperas y tweens son del nodo, así que una corrutina muere con él.

signal defeated(fighter: ArenaFighter)
signal health_changed
signal attack_finished

@export var config: EntityConfig

@onready var body: Node3D = get_node_or_null(^"%Body")
@onready var hurtbox: Hurtbox = get_node_or_null(^"%Hurtbox")
@onready var health: Health = get_node_or_null(^"Health")
## Los movimientos dibujados (rugido, saltos, temblar, morir); el código elige cuál y cuándo.
@onready var moves: AnimationPlayer = get_node_or_null(^"%Moves")

var arena := Rect2()
var pace := 1.0
var may_attack: Callable
var peers: Array[ArenaFighter] = []
var _turn := 0
var _tweens: Array[Tween] = []
var _home := Vector3.ZERO

var is_dead: bool:
	get:
		return _is_dead()


func _ready() -> void:
	health.max_health = config.max_health
	health.current = config.max_health
	hurtbox.team = config.team
	hurtbox.hit.connect(_on_hit)
	health.died.connect(_die)
	_home = global_position


func start() -> void:
	if not _is_idle() or is_dead:
		return
	add_to_group(Enemy.GROUP)
	config.apply_to(self)
	_run()


func roar() -> void:
	pass


@abstract func reset() -> void
@abstract func is_vulnerable() -> bool
@abstract func _is_idle() -> bool
@abstract func _run() -> void
@abstract func _die() -> void


func _is_dead() -> bool:
	return health.current <= 0


func _interrupt() -> void:
	_turn += 1
	for tween in _tweens:
		if tween.is_valid():
			tween.kill()
	_tweens.clear()
	if moves:
		moves.stop(true)
	_on_interrupt()
	attack_finished.emit()


func _on_interrupt() -> void:
	pass


## Fuera de su momento vulnerable todo rebota en chispas; _react_to atiende antes los golpes especiales.
func _on_hit(info: DamageInfo) -> void:
	if is_dead or _is_idle():
		return
	if _react_to(info):
		return
	if not is_vulnerable():
		hurtbox.surface = "stone"
		Feel.burst(&"sparks", _spark_point(), Vector3.UP)
		Feel.sfx(&"block", body.global_position)
		return
	hurtbox.surface = _wound_surface()
	if health.damage(info.amount):
		Log.info(&"combat", name, "recibió", info.amount, "de daño. Vida:", health.current)
		health_changed.emit()


func _react_to(_info: DamageInfo) -> bool:
	return false


func _spark_point() -> Vector3:
	return body.global_position


func _wound_surface() -> String:
	return "flesh"


func _wait(seconds: float, paced := true) -> Signal:
	return Tweens.wait(self, seconds / pace if paced else seconds)


## Corre un clip de %Moves desde el principio: `paced` lo acelera con la pelea; `seconds` lo estira a esa duración.
func _clip(clip: StringName, paced := true, seconds := 0.0) -> void:
	var length := moves.get_animation(clip).length
	moves.speed_scale = (pace if paced else 1.0) * (length / seconds if seconds > 0.0 else 1.0)
	moves.stop(true)
	moves.play(clip)


func _after(seconds: float, callback: Callable) -> void:
	Tweens.wait(self, seconds).connect(callback, CONNECT_ONE_SHOT)


func _new_tween() -> Tween:
	_tweens = _tweens.filter(func(tween: Tween) -> bool: return tween.is_valid())
	var tween := create_tween()
	_tweens.append(tween)
	return tween


func _tween_to(target: Object, property: NodePath, value: Variant, seconds: float) -> PropertyTweener:
	return _new_tween().tween_property(target, property, value, seconds / pace)


func _clamp_to_arena(point: Vector3) -> Vector3:
	if arena.size == Vector2.ZERO:
		return Vector3(point.x, global_position.y, point.z)
	return Vector3(clampf(point.x, arena.position.x, arena.end.x), global_position.y, clampf(point.z, arena.position.y, arena.end.y))
