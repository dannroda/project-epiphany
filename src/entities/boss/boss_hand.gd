@tool
class_name BossHand
extends Node3D
## Guantelete del jefe: tres mallas hermanas, una por pose; se ve una sola.
## Solo recibe daño aturdida; si no, el golpe rebota en el hierro.

signal state_changed(state: State)
signal downed

enum Pose { OPEN, FIST, CLAW }
enum State { READY, BUSY, STUNNED, DOWN }

@export var pose := Pose.OPEN:
	set(value):
		pose = value
		if is_inside_tree():
			_show_pose()
@export var damage := 4
@export var knockback := 10.0

var state := State.READY
var _stun_left := 0.0

@onready var health: Health = $Health
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var attack_runner: AttackRunner = $AttackRunner


func _ready() -> void:
	_show_pose()
	if Engine.is_editor_hint():
		return
	hurtbox.team = EntityConfig.Team.ENEMY
	for hitbox: Hitbox in attack_runner.hitboxes.values():
		hitbox.team = EntityConfig.Team.ENEMY
		hitbox.damage_factory = _make_damage
	hurtbox.hit.connect(_on_hit)
	health.died.connect(_on_died)
	HitFlash.attach(self, health)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or state != State.STUNNED:
		return
	_stun_left -= delta
	if _stun_left <= 0.0:
		set_state(State.READY)


func is_available() -> bool:
	return state == State.READY


func set_state(value: State) -> void:
	if value == state:
		return
	state = value
	if state != State.BUSY:
		attack_runner.stop()
	state_changed.emit(state)


func stun(seconds: float) -> void:
	if state == State.DOWN:
		return
	_stun_left = seconds
	set_state(State.STUNNED)


## Fase 2: vuelve con la vida llena.
func regenerate() -> void:
	health.reset(health.max_health)
	set_state(State.READY)


func _make_damage() -> DamageInfo:
	var info := DamageInfo.new()
	info.amount = damage
	info.knockback = knockback
	info.source = self
	return info


func _on_hit(info: DamageInfo) -> void:
	if state == State.DOWN:
		return
	if state != State.STUNNED:
		if info.stun_time > 0.0:
			stun(info.stun_time)
			Feel.sfx(&"deny", global_position)
		else:
			Feel.sfx(&"block", global_position)
			Feel.burst(&"sparks", global_position, Vector3.UP)
		return
	health.damage(info.amount)


func _on_died() -> void:
	set_state(State.DOWN)
	downed.emit()


func _show_pose() -> void:
	$Open.visible = pose == Pose.OPEN
	$Fist.visible = pose == Pose.FIST
	$Claw.visible = pose == Pose.CLAW
