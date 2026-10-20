class_name Hitbox
extends Area3D
## Se prende con activate() y se apaga con deactivate() (AttackRunner, jefes, trampas) o queda siempre activa (proyectiles).

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
## Solo un Hitbox común duerme sin _airborne; las subclases (proyectil, martillo, explosión) usan su propio cuadro.
var _sleeps := false


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(func(area: Area3D) -> void:
		if area is Hurtbox:
			_airborne.erase(area))
	body_entered.connect(_on_body_entered)
	_sleeps = get_script() == Hitbox
	set_physics_process(not _sleeps)


func _physics_process(_delta: float) -> void:
	for i in range(_airborne.size() - 1, -1, -1):
		var hurtbox := _airborne[i]
		if not is_instance_valid(hurtbox) or not monitoring:
			_airborne.remove_at(i)
		elif hurtbox.is_grounded():
			_airborne.remove_at(i)
			_on_area_entered(hurtbox)
	if _sleeps:
		set_physics_process(not _airborne.is_empty())


## Cada activación es un golpe nuevo: olvida a quién le pegó la anterior.
func activate(attack: AttackData = null, deferred := false) -> void:
	active_attack = attack
	if deferred:
		set_deferred(&"monitoring", true)
	else:
		monitoring = true


func deactivate() -> void:
	active_attack = null
	set_deferred(&"monitoring", false)


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
	if ground_only and not hurtbox.is_grounded():
		if hits_on_landing and not hurtbox in _airborne:
			_airborne.append(hurtbox)
			set_physics_process(true)
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
