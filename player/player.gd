class_name PlayerCharacter
extends CharacterBody3D

const SHIELD_THRUST: AttackData = preload("res://data/attacks/shield_thrust.tres")

## El HUD sacude el slot del botón que no se pudo usar.
signal item_denied(button: int)

@export var config: EntityConfig
@export var block_angle_deg := 60.0
@export var block_pushback := 0.3
## Sin bloquear, el escudo en la espalda frena los proyectiles que llegan dentro de este cono.
@export var back_shield_angle_deg := 45.0

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
@onready var input_buffer: InputBuffer = $InputBuffer
@onready var aim: Aim = $Aim

var guard_tween: Tween

var is_dead: bool:
	get:
		return health.current <= 0
var _block_cone: MeshInstance3D


func _ready() -> void:
	add_to_group(&"player")
	_register_monitors()
	config.apply_to(self)
	hurtbox.team = config.team
	hitbox.team = config.team
	hitbox.damage_factory = _make_damage
	hurtbox.hit.connect(_on_hit)
	hitbox.landed.connect(_on_hit_landed)
	HitFlash.attach($ModelController/Visuals, health)
	health.died.connect(_on_died)
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


## El ítem asignado al botón, si lo tiene y se puede usar ahora.
func usable_item(button: int) -> ItemData:
	var item := Items.get_item(GameState.item_buttons[button]) if GameState.item_buttons[button] != &"" else null
	if item == null or item.behavior == null or not GameState.inventory.has(item.id):
		return null
	return item if item.behavior.can_use(make_item_context(), item) else null


func make_item_context() -> ItemUseContext:
	var ctx := ItemUseContext.new()
	ctx.user = self
	ctx.origin = equipment.weapon_socket.global_position if equipment.weapon_socket else global_position + Vector3.UP
	ctx.direction = aim.get_direction()
	ctx.inventory = GameState.inventory
	ctx.throw_to = aim.throw_point()
	return ctx


## Al cruzar a otra sala: camina solo hacia adentro mientras la cámara se desliza.
func begin_room_transition(direction: Vector3, duration: float) -> void:
	if is_dead:
		return
	movement_state.blackboard.set_var("transition_dir", direction)
	movement_state.blackboard.set_var("transition_time", duration)
	movement_state.dispatch("transition")


func can_interact() -> bool:
	var state := movement_state.get_active_state()
	return state != null and state.name in [&"Idle", &"Moving"]


## Lo llaman cofres y recompensas después de GameState.give().
func play_item_get(item: ItemData, amount: int = 1) -> void:
	movement_state.blackboard.set_var("got_item", item)
	movement_state.blackboard.set_var("got_amount", amount)
	movement_state.dispatch("item_get")


func deny_item(button: int) -> void:
	Feel.sfx(&"deny", global_position)
	item_denied.emit(button)


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
		equipment.show_shield_in_hand(in_hand)


func _make_damage() -> DamageInfo:
	if equipment.weapon:
		return equipment.weapon.make_damage(self)
	return config.make_damage(self)


func _sync_health() -> void:
	health.reset(GameState.max_health)


func _on_hit(info: DamageInfo) -> void:
	if _shield_stops(info):
		return
	var amount := maxi(1, roundi(info.amount * (1.0 - equipment.damage_reduction())))
	if not health.damage(amount):
		return
	Log.info(&"combat", "El player recibió", amount, "de daño de", info.source.name if info.source else "?", "· Vida:", health.current)
	movement_state.blackboard.set_var("last_hit", info)
	Feel.shake(Feel.settings.shake_take)
	Feel.sfx(&"hurt", global_position)
	Feel.hit_stop([self, info.source], Feel.settings.hit_stop_take)
	if is_dead:
		Log.info(&"combat", "El player murió:", info.source.name if info.source else "?", "le sacó", amount, "con", health.max_health, "de vida máxima")
		return
	movement_state.dispatch("hurt")


func _on_hit_landed(target: Hurtbox) -> void:
	Feel.hit_stop([self, target.get_parent()], Feel.settings.hit_stop_give)
	Feel.shake(Feel.settings.shake_give)
	Feel.sfx(&"hit", target.global_position)


func _on_died() -> void:
	movement_state.dispatch("die")


## El modelo KayKit mira a +Z local.
func _is_in_front(point: Vector3) -> bool:
	var forward := model.global_basis.z
	forward.y = 0.0
	var to_point := point - global_position
	to_point.y = 0.0
	if to_point.is_zero_approx() or forward.is_zero_approx():
		return true
	return rad_to_deg(forward.angle_to(to_point)) <= block_angle_deg


func shield() -> ItemData:
	var id: StringName = GameState.equipment.get(ItemData.Category.SHIELD, &"")
	return Items.get_item(id) if id != &"" else null


func shield_reflects() -> bool:
	var equipped := shield()
	return equipped != null and equipped.reflects


func shield_protects(info: DamageInfo) -> bool:
	var equipped := shield()
	var kind := info.element if info.element != &"" else &"physical"
	return equipped != null and kind in equipped.protects_against


## De frente bloqueando: el espejo refleja lo reflejable y el escudo frena lo que protege; lo demás pasa.
## En la espalda sin bloquear: solo proyectiles; el espejo los devuelve a quien los tiró.
func _shield_stops(info: DamageInfo) -> bool:
	if info.source == null:
		return false
	var projectile := info.source as Projectile
	if is_blocking() and _is_in_front(info.source.global_position):
		if projectile and info.reflectable and shield_reflects():
			_reflect(projectile, aim.get_direction(), true)
			return true
		if shield_protects(info):
			_on_blocked(info)
			return true
		Log.debug(&"combat", "El escudo no frena", info.element)
		Feel.burst(&"shards", global_position + model.global_basis.z * 0.6 + Vector3.UP * 1.1, model.global_basis.z)
		return false
	if projectile and not is_blocking() and _is_behind(projectile.global_position):
		if info.reflectable and shield_reflects():
			var back := projectile.shooter.global_position - global_position if is_instance_valid(projectile.shooter) else -projectile.velocity
			_reflect(projectile, back, false)
			return true
		if shield_protects(info):
			Log.debug(&"combat", "Frenado por el escudo de la espalda:", projectile.name)
			Feel.burst(&"sparks", projectile.global_position, -projectile.velocity.normalized())
			Feel.sfx(&"block", global_position)
			return true
	return false


## El haz de luz que toca al player: el escudo espejo lo devuelve (de frente bloqueando, hacia la mira;
## en la espalda, rebota). Con otro escudo o sin cubrirse, el haz se corta acá (null).
## Devuelve la nueva dirección y el punto de salida: el escudo, delante del centro del player.
func light_hit(direction: Vector3, point: Vector3) -> Variant:
	if not shield_reflects():
		return null
	var from := point - direction
	var out: Vector3
	if is_blocking() and _is_in_front(from):
		out = aim.get_direction()
	elif not is_blocking() and _is_behind(from):
		var back := -model.global_basis.z
		back.y = 0.0
		out = direction.bounce(back.normalized()).normalized()
	else:
		return null
	var center := Vector3(global_position.x, point.y, global_position.z)
	return {direction = out, origin = center + out * 0.6}


func _is_behind(point: Vector3) -> bool:
	var back := -model.global_basis.z
	back.y = 0.0
	var to_point := point - global_position
	to_point.y = 0.0
	if to_point.is_zero_approx() or back.is_zero_approx():
		return false
	return rad_to_deg(back.angle_to(to_point)) <= back_shield_angle_deg


## Escudo espejo: el proyectil vuelve en esa dirección y pasa a ser del player.
func _reflect(projectile: Projectile, direction: Vector3, front: bool) -> void:
	projectile.reflect(direction, config.team)
	Log.debug(&"combat", "Reflejado:", projectile.name, "hacia", direction)
	if front:
		anim_tree.set(&"parameters/BlockHit/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		Feel.shake(Feel.settings.shake_block)
	Feel.burst(&"sparks", projectile.global_position, direction)
	Feel.sfx(&"reflect", global_position)


func _on_blocked(info: DamageInfo) -> void:
	Log.debug(&"combat", "Bloqueado:", info.source.name, info.amount, "de daño")
	anim_tree.set(&"parameters/BlockHit/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	var away := global_position - info.source.global_position
	away.y = 0.0
	if not away.is_zero_approx():
		move_and_collide(away.normalized() * block_pushback)
	Feel.burst(&"sparks", global_position + model.global_basis.z * 0.6 + Vector3.UP * 1.1, model.global_basis.z)
	Feel.sfx(&"block", global_position)
	Feel.shake(Feel.settings.shake_block)


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
