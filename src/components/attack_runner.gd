class_name AttackRunner
extends Node
## Enciende y apaga hitboxes según el progreso del ataque. Lo comparten player y enemigos.

## Las Hitbox hijas de este nodo se registran por nombre: Front → &"front".
@export var hitbox_root: Node
var hitboxes: Dictionary[StringName, Hitbox] = {}

var current: AttackData
var _elapsed := 0.0
var _length := 1.0
var _speed := 1.0


func _ready() -> void:
	set_physics_process(false)
	if hitbox_root:
		for child in hitbox_root.get_children():
			if child is Hitbox:
				hitboxes[StringName(String(child.name).to_snake_case())] = child
	for hitbox in hitboxes.values():
		if hitbox:
			hitbox.set_deferred(&"monitoring", false)


## from_time: segundos ya transcurridos de la animación (si arrancó antes, como el aviso de BTAttack).
func start(attack: AttackData, length: float, speed: float = 1.0, from_time: float = 0.0) -> void:
	stop()
	current = attack
	_length = maxf(length, 0.001)
	_speed = speed
	_elapsed = from_time
	set_physics_process(true)


## Se llama también al salir del estado: garantiza que nunca quede una hitbox activa.
func stop() -> void:
	if current:
		_set_active(false)
	current = null
	set_physics_process(false)


func is_running() -> bool:
	return current != null


func is_active() -> bool:
	var hitbox: Hitbox = hitboxes.get(current.hitbox) if current else null
	return hitbox != null and hitbox.active_attack != null


func _physics_process(delta: float) -> void:
	_elapsed += delta * _speed
	var t := _elapsed / _length
	_set_active(t >= current.active_from and t < current.active_to)
	if t >= 1.0:
		stop()


func _set_active(active: bool) -> void:
	var hitbox: Hitbox = hitboxes.get(current.hitbox)
	if hitbox == null or (hitbox.active_attack != null) == active:
		return
	hitbox.active_attack = current if active else null
	hitbox.set_deferred(&"monitoring", active)
