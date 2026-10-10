class_name Enemy
extends CharacterBody3D

const KNOCKBACK_FRICTION: float = 18.0
const KNOCKBACK_LIFT: float = 4.0
const DEAD_COLLISION_LAYER: int = 4

signal defeated(enemy: Enemy)

@export var config: EntityConfig

@onready var anim_player: AnimationPlayer = $ModelController/AnimationPlayer
@onready var bt_player: BTPlayer = $BTPlayer
@onready var model: Node3D = $ModelController
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
var _guard_down_until := 0

var is_dead: bool:
	get:
		return health.current <= 0


func _ready() -> void:
	config.apply_to(self)
	if config.model:
		_swap_model(config.model)
	add_to_group(&"enemies")
	_register_monitors()
	health.max_health = config.max_health
	health.current = config.max_health
	hurtbox.team = config.team
	hitbox.team = config.team
	hitbox.damage_factory = config.make_damage.bind(self)
	hurtbox.hit.connect(_on_hit)
	flash = HitFlash.attach($ModelController/Visuals, health)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	bt_player.blackboard.set_var("is_hit", false)
	bt_player.blackboard.set_var("is_dead", false)
	bt_player.blackboard.set_var("stunned", false)
	bt_player.blackboard.set_var("target", null)
	for body in model.find_children("*", "StaticBody3D", true, false):
		for shape in body.find_children("*", "CollisionShape3D", true, false):
			(shape as CollisionShape3D).disabled = true


func _swap_model(scene: PackedScene) -> void:
	var old := $ModelController/Visuals
	var visuals := scene.instantiate()
	old.name = &"OldVisuals"
	old.get_parent().add_child(visuals)
	old.get_parent().move_child(visuals, old.get_index())
	old.queue_free()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	_knockback.x = move_toward(_knockback.x, 0.0, KNOCKBACK_FRICTION * delta)
	_knockback.z = move_toward(_knockback.z, 0.0, KNOCKBACK_FRICTION * delta)
	velocity.x = desired_velocity.x + _knockback.x
	velocity.z = desired_velocity.z + _knockback.z
	move_and_slide()
	_turn(delta)


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


func is_guarding() -> bool:
	return config.guards_front and not is_dead and Time.get_ticks_msec() >= _guard_down_until


## Escudo de frente: frena todo salvo explosiones; un golpe que aturde le baja la guardia.
func _guard_stops(info: DamageInfo) -> bool:
	if not is_guarding() or info.source == null or info.element == &"explosive":
		return false
	var to_source := info.source.global_position - global_position
	to_source.y = 0.0
	if to_source.is_zero_approx() or rad_to_deg(facing().angle_to(to_source)) > config.guard_angle_deg:
		return false
	if info.stun_time > 0.0:
		_guard_down_until = Time.get_ticks_msec() + int(config.guard_break_time * 1000.0)
		Log.debug(&"combat", name, "bajó la guardia")
		Feel.sfx(&"deny", global_position)
	else:
		Feel.sfx(&"block", global_position)
	Feel.burst(&"sparks", global_position + Vector3.UP * 1.1 + to_source.normalized() * 0.5, to_source.normalized())
	return true


func _on_hit(info: DamageInfo) -> void:
	if _guard_stops(info):
		return
	if not health.damage(info.amount):
		return
	Log.info(&"combat", name, "recibió", info.amount, "de daño. Vida:", health.current)
	if info.stun_time > 0.0 and not is_dead:
		bt_player.blackboard.set_var("stunned", true)
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
	bt_player.blackboard.set_var("is_hit", true)
	bt_player.restart()


func _on_died() -> void:
	Log.info(&"combat", name, "murió")
	remove_from_group(&"targetable")
	attack_runner.stop()
	stop_moving()
	hurtbox.set_deferred(&"monitorable", false)
	defeated.emit(self)
	bt_player.blackboard.set_var("is_dead", true)
	bt_player.restart()


func on_death_finished() -> void:
	bt_player.active = false
	collision_layer = DEAD_COLLISION_LAYER
	if config.drops:
		config.drops.drop_at.call_deferred(global_position, get_parent())
	Log.debug(&"combat", name, "terminó de morir")


static func _register_monitors() -> void:
	if Performance.has_custom_monitor("epiphany/enemies_alive"):
		return
	Performance.add_custom_monitor("epiphany/enemies_alive", func() -> int:
		var tree := Engine.get_main_loop() as SceneTree
		return tree.get_nodes_in_group(&"enemies").filter(func(e: Node) -> bool: return e is Enemy and not e.is_dead).size())
