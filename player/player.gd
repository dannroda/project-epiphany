class_name PlayerCharacter
extends CharacterBody3D

const SHIELD_THRUST: AttackData = preload("res://data/attacks/shield_thrust.tres")

@export var config: EntityConfig

@onready var model: Node3D = $ModelController
@onready var anim_player: AnimationPlayer = $ModelController/AnimationPlayer
@onready var anim_tree: AnimationTree = $ModelController/AnimationTree
@onready var movement_state: LimboHSM = $MovementState
@onready var health: Health = $Health
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var hitbox: Hitbox = $ModelController/Hitboxes/Front
@onready var attack_runner: AttackRunner = $AttackRunner
@onready var equipment: Equipment = $Equipment
@onready var targeting: Targeting = $Targeting

var guard_tween: Tween


func _ready() -> void:
	add_to_group(&"player")
	_register_monitors()
	config.apply_to(self)
	hurtbox.team = config.team
	hitbox.team = config.team
	hitbox.damage_factory = _make_damage
	hurtbox.hit.connect(_on_hit)
	GameState.loaded.connect(_sync_health)
	_sync_health()
	targeting.target_changed.connect(func(target: Node3D) -> void: movement_state.blackboard.set_var("target", target))
	movement_state.initialize(self)
	movement_state.set_active(true)


func _physics_process(delta: float) -> void:
	movement_state.update(delta)
	_watch_debug_values()


func is_blocking() -> bool:
	return movement_state.blackboard.get_var("is_blocking", false)


## El ataque que toca según lo que tiene en la mano y si está bloqueando.
func current_attack() -> AttackData:
	if is_blocking():
		return SHIELD_THRUST
	var weapon := equipment.weapon
	if weapon and weapon.behavior is MeleeBehavior:
		return (weapon.behavior as MeleeBehavior).get_attack(0)
	return null


func set_guard(active: bool) -> void:
	if guard_tween and guard_tween.is_valid():
		guard_tween.kill()
	guard_tween = create_tween()
	if active:
		_show_shield_in_hand(true)
		guard_tween.tween_property(anim_tree, "parameters/GuardBlend/blend_amount", 1.0, 0.15)
	else:
		guard_tween.tween_property(anim_tree, "parameters/GuardBlend/blend_amount", 0.0, 0.15)
		guard_tween.finished.connect(func() -> void:
			if not is_blocking():
				_show_shield_in_hand(false))


func _show_shield_in_hand(in_hand: bool) -> void:
	if equipment.shield_in_hand:
		equipment.shield_in_hand.visible = in_hand
		equipment.shield_on_back.visible = not in_hand


func _make_damage() -> DamageInfo:
	if equipment.weapon:
		return equipment.weapon.make_damage(self)
	return config.make_damage(self)


func _sync_health() -> void:
	health.max_health = GameState.max_health
	health.current = GameState.max_health


func _on_hit(info: DamageInfo) -> void:
	if health.damage(info.amount):
		Log.info(&"combat", "El player recibió", info.amount, "de daño. Vida:", health.current)


func _watch_debug_values() -> void:
	var state := movement_state.get_active_state()
	DebugOverlay.watch("player/state", state.name if state else &"-")
	DebugOverlay.watch("player/animation", anim_tree.get(&"parameters/Movement/current_state"))
	DebugOverlay.watch("player/velocity", velocity.snappedf(0.01))
	DebugOverlay.watch("player/target", targeting.current.name if targeting.current else &"-")
	DebugOverlay.watch("player/health", "%d / %d" % [health.current, health.max_health])


static func _register_monitors() -> void:
	if Performance.has_custom_monitor("epiphany/target_locked"):
		return
	Performance.add_custom_monitor("epiphany/target_locked", func() -> int:
		var tree := Engine.get_main_loop() as SceneTree
		var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
		return 1 if player and player.targeting.current else 0)
