class_name Hitbox
extends Area3D
## La enciende y apaga AttackRunner (ataques) o queda siempre activa (proyectiles, trampas).

signal landed(hurtbox: Hurtbox)

## Ondas por el piso (golpe de las manos del jefe): no le pegan a quien está en el aire (salto de la pluma).
@export var ground_only := false
## Con ground_only: el que entró en el aire y cae adentro también recibe (pinchos).
@export var hits_on_landing := false
## Todo lo que pega es golpe fuerte (DamageInfo.strong), como el martillazo; un ataque lo pide con AttackData.strong.
@export var strong := false

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
## hits_on_landing: los que entraron en el aire; les pega si tocan el piso adentro.
var _airborne: Array[Hurtbox] = []


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(func(area: Area3D) -> void:
		if area is Hurtbox:
			_airborne.erase(area))
	body_entered.connect(_on_body_entered)


func _physics_process(_delta: float) -> void:
	for hurtbox in _airborne.duplicate():
		if not is_instance_valid(hurtbox) or not monitoring:
			_airborne.erase(hurtbox)
		elif (hurtbox.get_parent() as PlayerCharacter).is_on_floor():
			_airborne.erase(hurtbox)
			_on_area_entered(hurtbox)


func build_damage() -> DamageInfo:
	var info: DamageInfo = damage_factory.call()
	info.team = team
	info.strong = info.strong or strong or (active_attack != null and active_attack.strong)
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
	var body := hurtbox.get_parent() as PlayerCharacter
	if ground_only and body and not body.is_on_floor():
		if hits_on_landing and not hurtbox in _airborne:
			_airborne.append(hurtbox)
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
