class_name PlayerCharacter
extends CharacterBody3D

const SHIELD_THRUST: AttackData = preload("res://data/attacks/shield_thrust.tres")

@export var config: EntityConfig
@export var block_angle_deg := 60.0
@export var block_pushback := 0.3

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
var _block_cone: MeshInstance3D


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
	_block_cone = _make_block_cone()


func _physics_process(delta: float) -> void:
	movement_state.update(delta)
	_watch_debug_values()


func _process(_delta: float) -> void:
	_update_block_cone()


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
	if is_blocking() and info.source and _is_in_front(info.source.global_position):
		_on_blocked(info)
		return
	var amount := maxi(1, roundi(info.amount * (1.0 - equipment.damage_reduction())))
	if not health.damage(amount):
		return
	Log.info(&"combat", "El player recibió", amount, "de daño de", info.source.name if info.source else "?", "· Vida:", health.current)
	movement_state.blackboard.set_var("last_hit", info)
	movement_state.dispatch("hurt")


## El modelo KayKit mira a +Z local.
func _is_in_front(point: Vector3) -> bool:
	var forward := model.global_basis.z
	forward.y = 0.0
	var to_point := point - global_position
	to_point.y = 0.0
	if to_point.is_zero_approx() or forward.is_zero_approx():
		return true
	return rad_to_deg(forward.angle_to(to_point)) <= block_angle_deg


func _on_blocked(info: DamageInfo) -> void:
	Log.debug(&"combat", "Bloqueado:", info.source.name, info.amount, "de daño")
	anim_tree.set(&"parameters/BlockHit/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	var away := global_position - info.source.global_position
	away.y = 0.0
	if not away.is_zero_approx():
		move_and_collide(away.normalized() * block_pushback)
	_spawn_sparks(global_position + model.global_basis.z * 0.6 + Vector3.UP * 1.1)


func _spawn_sparks(at: Vector3) -> void:
	var sparks := CPUParticles3D.new()
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.amount = 14
	sparks.lifetime = 0.25
	sparks.spread = 70.0
	sparks.direction = model.global_basis.z
	sparks.initial_velocity_min = 3.0
	sparks.initial_velocity_max = 5.0
	sparks.gravity = Vector3(0, -6, 0)
	var mesh := SphereMesh.new()
	mesh.radius = 0.025
	mesh.height = 0.05
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.85, 0.4)
	mesh.material = material
	sparks.mesh = mesh
	get_tree().current_scene.add_child(sparks)
	sparks.global_position = at
	sparks.emitting = true
	sparks.finished.connect(sparks.queue_free)


func _make_block_cone() -> MeshInstance3D:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 12
	var half := deg_to_rad(block_angle_deg)
	for i in steps:
		var a := -half + 2.0 * half * i / steps
		var b := -half + 2.0 * half * (i + 1) / steps
		mesh.surface_add_vertex(Vector3(0, 0.05, 0))
		mesh.surface_add_vertex(Vector3(sin(a), 0.05, cos(a)) * 1.5)
		mesh.surface_add_vertex(Vector3(sin(b), 0.05, cos(b)) * 1.5)
	mesh.surface_end()
	var cone := MeshInstance3D.new()
	cone.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	cone.material_override = material
	cone.visible = false
	model.add_child(cone)
	return cone


func _update_block_cone() -> void:
	_block_cone.visible = DebugOverlay.visible
	if _block_cone.visible:
		var color := Color(0.3, 0.8, 1.0, 0.35) if is_blocking() else Color(1, 1, 1, 0.12)
		(_block_cone.material_override as StandardMaterial3D).albedo_color = color


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
	Performance.add_custom_monitor("epiphany/player_hp", func() -> int:
		var tree := Engine.get_main_loop() as SceneTree
		var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
		return player.health.current if player else 0)
	Performance.add_custom_monitor("epiphany/target_locked", func() -> int:
		var tree := Engine.get_main_loop() as SceneTree
		var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
		return 1 if player and player.targeting.current else 0)
