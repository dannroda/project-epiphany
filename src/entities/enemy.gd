class_name Enemy
extends CharacterBody3D

const GROUP := &"enemies"
const KNOCKBACK_FRICTION: float = 18.0
const KNOCKBACK_LIFT: float = 4.0
const DEAD_COLLISION_LAYER: int = 4
## Claves del blackboard que leen los árboles de comportamiento (BTCheckVar en los .tres).
const BB_IS_HIT := &"is_hit"
const BB_IS_DEAD := &"is_dead"
const BB_STUNNED := &"stunned"
const BB_TARGET := &"target"
## Cuánto se puede correr el destino antes de pedir otro camino (15.20).
const REPATH_DISTANCE := 0.25

signal defeated(enemy: Enemy)

@export var config: EntityConfig
## Variantes de mazmorra (guerreros/): el cuerpo de su mazmorra en vez de config.model; la config es la del tipo.
@export var visuals: PackedScene
## El cuerpo queda en el piso este rato y después se hunde en una nube de polvo (11.58); el drop queda.
@export var corpse_time := 4.0
@export var sink_time := 1.0
@export var sink_depth := 0.9
## Escudo de frente (EnemyGuard) y coraza (EnemyArmor), en las escenas que los tienen.
@export var guard: EnemyGuard
@export var armor: EnemyArmor

@onready var anim_player: AnimationPlayer = $ModelController/AnimationPlayer
@onready var bt_player: BTPlayer = $BTPlayer
@onready var model: Node3D = $ModelController
## El hundimiento después de morir (clip sink, que al final lo libera).
@onready var sink: AnimationPlayer = $Sink
@onready var health: Health = $Health
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var hitbox: Hitbox = $ModelController/Hitboxes/Front
@onready var attack_runner: AttackRunner = $AttackRunner
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

## Lo que pide la IA; el empujón va aparte y se suma.
var desired_velocity := Vector3.ZERO
var flash: HitFlash
var _knockback := Vector3.ZERO
var _facing_goal := Vector3.ZERO
var _recoil_left := 0.0
var _airborne := false
## Donde deambula: donde empezó (o donde cayó), su sala y, en el overworld, las zonas de su región.
var _home := Vector3.INF
var _path_goal := Vector3.INF
var _home_room: Room
var _home_region: Array[AreaZone] = []
## Cuánto falta para el golpe que está avisando (INF si no avisa nada): lo lee el contraataque del player.
var _strike_left := INF

## 0 en el piso, 1 hundido `sink_depth`; lo anima el clip sink.
var sunk := 0.0:
	set(value):
		sunk = value
		if model:
			model.position.y = -sink_depth * value

var is_dead: bool:
	get:
		return health.current <= 0


func _ready() -> void:
	config.apply_to(self)
	var body_scene := visuals if visuals else config.model
	if body_scene:
		_swap_model(body_scene)
	add_to_group(GROUP)
	_register_monitors()
	health.max_health = config.max_health
	health.current = config.max_health
	hurtbox.team = config.team
	hitbox.team = config.team
	hitbox.damage_factory = config.make_damage.bind(self)
	hurtbox.hit.connect(_on_hit)
	flash = %HitFlash
	flash.cover($ModelController/Visuals)
	if guard:
		guard.blocked.connect(func(push: Vector3) -> void: _knockback = push)
	if armor:
		armor.broken.connect(func() -> void: bt_player.blackboard.set_var(BB_STUNNED, true))
	for held in model.find_children("*", "BoneAttachment3D", true, false):
		flash.cover(held)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	bt_player.blackboard.set_var(BB_IS_HIT, false)
	bt_player.blackboard.set_var(BB_IS_DEAD, false)
	bt_player.blackboard.set_var(BB_STUNNED, false)
	bt_player.blackboard.set_var(BB_TARGET, null)
	for body in model.find_children("*", "StaticBody3D", true, false):
		for shape in body.find_children("*", "CollisionShape3D", true, false):
			(shape as CollisionShape3D).disabled = true


func _swap_model(scene: PackedScene) -> void:
	var old := $ModelController/Visuals
	var fresh := scene.instantiate()
	var parent := old.get_parent()
	old.name = &"OldVisuals"
	parent.add_child(fresh)
	parent.move_child(fresh, old.get_index())
	parent.remove_child(old)
	old.queue_free()


func _physics_process(delta: float) -> void:
	_strike_left -= delta
	if _recoil_left > 0.0:
		_recoil_left -= delta
		if _recoil_left <= 0.0 and not is_dead:
			bt_player.active = true
			bt_player.restart()
	if not is_on_floor():
		velocity += get_gravity() * delta
	_knockback.x = move_toward(_knockback.x, 0.0, KNOCKBACK_FRICTION * delta)
	_knockback.z = move_toward(_knockback.z, 0.0, KNOCKBACK_FRICTION * delta)
	velocity.x = desired_velocity.x + _knockback.x
	velocity.z = desired_velocity.z + _knockback.z
	move_and_slide()
	if not is_on_floor():
		_airborne = true
	elif _airborne:
		_airborne = false
		_join_floor_below()
		if _home != Vector3.INF and absf(global_position.y - _home.y) > 1.0:
			_home = Vector3.INF
	_turn(delta)
	if guard:
		guard.update(delta, not is_dead and not _is_attacking())


## Si cayó por un hueco pasa al piso de abajo: los pisos de arriba del player se ocultan y lo dejarían invisible.
func _join_floor_below() -> void:
	var here := DungeonFloor.of(self)
	if here == null:
		return
	var landed := DungeonFloor.at_height(get_tree(), global_position.y)
	if landed and landed != here:
		reparent.call_deferred(landed)


## Un punto al azar de la navmesh a `wander_radius` de su lugar y en su misma sala; INF si no hay (radio 0, navmesh
## sin sincronizar o todo cae fuera: un abismo, otra sala).
func wander_point() -> Vector3:
	home()
	var map := nav_agent.get_navigation_map()
	if config.wander_radius <= 0.0 or NavigationServer3D.map_get_iteration_id(map) == 0:
		return Vector3.INF
	for i in 6:
		var angle := randf() * TAU
		var candidate := _home + Vector3(cos(angle), 0.0, sin(angle)) * randf_range(0.3, 1.0) * config.wander_radius
		var point := NavigationServer3D.map_get_closest_point(map, candidate)
		if Vector2(point.x - candidate.x, point.z - candidate.z).length() > 0.5 or absf(point.y - _home.y) > 1.0:
			continue
		if _home_room and not _home_room.contains(point):
			continue
		return point
	return Vector3.INF


## El que ya persigue no suelta al player mientras sigan los dos en su sala de dungeon, o mientras el player siga en
## su región de persecución del overworld.
func shares_room(point: Vector3) -> bool:
	home()
	if _home_room != null:
		return _home_room.contains(point) and _home_room.contains(global_position)
	return _home_region.any(func(zone: AreaZone) -> bool: return zone.contains(point))


## Su lugar: donde estaba la primera vez que se pidió (o donde cayó, si bajó de nivel).
func home() -> Vector3:
	if _home == Vector3.INF:
		_home = global_position
		_home_room = null
		for room: Room in get_tree().get_nodes_in_group(Room.GROUP):
			if room.contains(_home):
				_home_room = room
		_home_region.clear()
		if _home_room == null:
			_home_region = AreaZone.region_at(get_tree(), _home)
	return _home


## El siguiente punto del camino a `point`. Asignar target_position recalcula el camino entero aunque no cambie, y con
## cada enemigo que deambula pidiéndolo en cada tick era lo más caro del cuadro en el G23 (15.20).
func path_to(point: Vector3) -> Vector3:
	if _path_goal.distance_squared_to(point) > REPATH_DISTANCE * REPATH_DISTANCE or nav_agent.is_navigation_finished():
		_path_goal = point
		nav_agent.target_position = point
	return nav_agent.get_next_path_position()


func move_toward_point(point: Vector3, speed: float) -> void:
	var direction := point - global_position
	direction.y = 0.0
	if direction.length() < 0.05:
		stop_moving()
		return
	desired_velocity = direction.normalized() * speed
	face_towards(point)


func stop_moving() -> void:
	desired_velocity = Vector3.ZERO


## El modelo mira a +Z local: la raíz mira (-Z) hacia el lado opuesto al punto. Con `turn_speed`, gira de a poco.
func face_towards(point: Vector3) -> void:
	var direction := point - global_position
	direction.y = 0.0
	if direction.is_zero_approx():
		return
	if config.turn_speed > 0.0:
		_facing_goal = direction.normalized()
		return
	look_at(global_position - direction, Vector3.UP)
	model.rotation = Vector3.ZERO


## Hacia dónde mira (en el plano).
func facing() -> Vector3:
	var forward := global_basis.z
	forward.y = 0.0
	return forward.normalized()


func _turn(delta: float) -> void:
	if _facing_goal.is_zero_approx():
		return
	var angle := facing().signed_angle_to(_facing_goal, Vector3.UP)
	var step := clampf(angle, -config.turn_speed * delta, config.turn_speed * delta)
	rotate_y(step)
	model.rotation = Vector3.ZERO
	if is_equal_approx(step, angle):
		_facing_goal = Vector3.ZERO


## El aviso de un ataque (pose quieta y destello) que pega dentro de `duration` segundos.
func telegraph(duration: float) -> void:
	flash.warn(duration)
	_strike_left = duration


func end_telegraph() -> void:
	_strike_left = INF


## Segundos hasta el golpe avisado; INF si no está avisando.
func strike_in() -> float:
	return _strike_left if _strike_left > -0.05 and not is_dead else INF


func is_guarding() -> bool:
	return guard != null and not is_dead and guard.is_up()


func shield_up() -> bool:
	return is_guarding() and guard.shield_up()


func _is_attacking() -> bool:
	return String(anim_player.current_animation).contains("Attack")


## Su golpe chocó contra un escudo: corta el ataque, retrocede y queda aturdido un instante, con el escudo bajo.
func recoil(seconds: float, from: Vector3) -> void:
	if is_dead:
		return
	if guard:
		guard.lower(seconds)
	attack_runner.stop()
	stop_moving()
	bt_player.active = false
	anim_player.play(&"General/Hit_B", 0.1)
	var away := (global_position - from) * Vector3(1, 0, 1)
	if not away.is_zero_approx():
		_knockback = away.normalized() * 3.0
	_recoil_left = seconds


func is_recoiling() -> bool:
	return _recoil_left > 0.0


func is_armored() -> bool:
	return armor != null and armor.is_on() and not is_dead


func _shielded_from(info: DamageInfo) -> bool:
	if is_dead:
		return false
	return (armor != null and armor.stops(info)) or (guard != null and guard.stops(info))


func _on_hit(info: DamageInfo) -> void:
	var stopped := _shielded_from(info)
	hurtbox.surface = "metal" if stopped else "flesh"
	if stopped:
		return
	if not health.damage(info.amount):
		return
	Log.info(&"combat", name, "recibió", info.amount, "de daño. Vida:", health.current)
	if info.stun_time > 0.0 and not is_dead:
		bt_player.blackboard.set_var(BB_STUNNED, true)
		Log.debug(&"combat", name, "quedó aturdido")
	if info.source == null:
		return
	var direction := global_position - info.source.global_position
	direction.y = 0.0
	if direction.is_zero_approx():
		return
	direction = direction.normalized()
	var strength := info.knockback * (1.0 - config.knockback_resistance)
	_knockback = direction * strength
	velocity.y = KNOCKBACK_LIFT * (1.0 - config.knockback_resistance)
	face_towards(info.source.global_position)


func _on_damaged(_amount: int) -> void:
	if is_dead:
		return
	bt_player.blackboard.set_var(BB_IS_HIT, true)
	bt_player.restart()


func _on_died() -> void:
	Log.info(&"combat", name, "murió")
	remove_from_group(Targeting.GROUP)
	attack_runner.stop()
	stop_moving()
	hurtbox.set_deferred(&"monitorable", false)
	defeated.emit(self)
	bt_player.blackboard.set_var(BB_IS_DEAD, true)
	bt_player.restart()


## reactions_bt (un BTSubtree) apaga is_hit / stunned acá: un BTSetVar del subárbol escribiría en su propio scope.
func clear_reaction(variable: StringName) -> void:
	bt_player.blackboard.set_var(variable, false)


func on_death_finished() -> void:
	bt_player.active = false
	collision_layer = DEAD_COLLISION_LAYER
	if config.drops:
		config.drops.drop_at.call_deferred(global_position, get_parent())
	Log.debug(&"combat", name, "terminó de morir")
	_sink_away()


func _sink_away() -> void:
	await Tweens.wait(self, corpse_time)
	if not is_inside_tree():
		return
	Feel.burst(&"dust", global_position + Vector3.UP * 0.1, Vector3.UP)
	sink.speed_scale = sink.get_animation(&"sink").length / sink_time
	sink.play(&"sink")


static func _register_monitors() -> void:
	if Performance.has_custom_monitor("epiphany/enemies_alive"):
		return
	Performance.add_custom_monitor("epiphany/enemies_alive", func() -> int:
		var tree := Engine.get_main_loop() as SceneTree
		return tree.get_nodes_in_group(GROUP).filter(func(e: Node) -> bool: return e is Enemy and not e.is_dead).size())
