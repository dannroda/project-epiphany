class_name Hitbox
extends Area3D
## La enciende y apaga AttackRunner (ataques) o queda siempre activa (proyectiles, trampas).

signal landed(hurtbox: Hurtbox)

## Ondas por el piso (golpe de las manos del jefe): no le pegan a quien está en el aire (salto de la pluma).
@export var ground_only := false

var team: EntityConfig.Team = EntityConfig.Team.NEUTRAL
## () -> DamageInfo. Player: ItemData del arma equipada. Enemigo: su EntityConfig.
var damage_factory: Callable
## Explosiones: daña a todos los equipos, incluido el propio.
var hits_all := false
## Lo setea AttackRunner al activar; null = sin multiplicadores.
var active_attack: AttackData:
	set(value):
		active_attack = value
		_already_hit.clear()

var _already_hit: Array[Hurtbox] = []


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)


func build_damage() -> DamageInfo:
	var info: DamageInfo = damage_factory.call()
	info.team = team
	if active_attack:
		info.amount = roundi(info.amount * active_attack.damage_multiplier)
		info.knockback *= active_attack.knockback_multiplier
		info.stun_time = active_attack.stun_time
	return info


func _on_area_entered(area: Area3D) -> void:
	var hurtbox := area as Hurtbox
	if hurtbox == null or (hurtbox.team == team and not hits_all) or not damage_factory.is_valid():
		return
	if hurtbox in _already_hit:
		return
	var body := hurtbox.get_parent() as CharacterBody3D
	if ground_only and body and not body.is_on_floor():
		return
	_already_hit.append(hurtbox)
	hurtbox.receive(build_damage())
	landed.emit(hurtbox)


## Objetos físicos sin Hurtbox (cajas, rocas): solo impulso.
func _on_body_entered(body: Node3D) -> void:
	if body is RigidBody3D and damage_factory.is_valid():
		var info := build_damage()
		var push := body.global_position - global_position
		push.y = 0.0
		body.apply_central_impulse(push.normalized() * info.knockback + Vector3.UP * 4.0)
