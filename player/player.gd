class_name PlayerCharacter
extends CharacterBody3D

const PlayerControls := preload("res://player/components/controls.gd")
## Los botones de ítem (X, Y), en orden.
const ITEM_ACTIONS: Array[StringName] = [&"item_1", &"item_2"]

const SWORD_STAB: AttackData = preload("res://data/attacks/sword_stab.tres")
const SILHOUETTE := preload("res://src/feel/occluded_silhouette.gdshader")

## El HUD sacude el slot del botón que no se pudo usar.
signal item_denied(button: int)
## Se soltó de un agarre a fuerza de botones.
signal escaped

@export var config: EntityConfig

@onready var model: Node3D = $ModelController
## Lo que se ve del caído en co-op (estado Spirit).
@onready var spirit: Node3D = $Spirit
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
@onready var carrier: Carrier = $Carrier
@onready var interaction_detector: InteractionDetector = $InteractionDetector
@onready var dodge_ghosts: DodgeGhosts = $DodgeGhosts
@onready var shield: Shield = $Shield
@onready var sword_charge: SwordCharge = $SwordCharge
## Lo que se retoca en el inspector (duración, gradiente, material) es del nodo; el ancho y la posición se ajustan al arma.
@onready var sword_trail: Trail3D = $ModelController/Skeleton3D/Hand_R/SwordTrail
@onready var tip_trail: Trail3D = $ModelController/Skeleton3D/Hand_R/TipTrail

## Qué controles lee (13.2); existe desde que se instancia, así `Players` le asigna el slot antes de sumarlo.
var controls := PlayerControls.new()
var _default_trail: Gradient
## Lo que frena el suelo (agua baja): multiplica la velocidad al caminar.
var ground_speed := 1.0
## Dónde pisó suelo por última vez (los pozos lo devuelven a esa orilla).
var last_ground := Vector3.ZERO

var is_dead: bool:
	get:
		return health.current <= 0


func _enter_tree() -> void:
	Players.register(self)


func _exit_tree() -> void:
	Players.unregister(self)


func _ready() -> void:
	add_to_group(&"player")
	anim_tree.tree_root = anim_tree.tree_root.duplicate(true)
	_register_monitors()
	config.apply_to(self)
	hurtbox.team = config.team
	for each: Hitbox in attack_runner.hitboxes.values():
		each.team = config.team
		each.damage_factory = _make_damage
		if each != hitbox:
			each.landed.connect(_on_hit_landed)
	hurtbox.hit.connect(_on_hit)
	hitbox.landed.connect(_on_hit_landed)
	var silhouette := ShaderMaterial.new()
	silhouette.shader = SILHOUETTE
	var flash: HitFlash = %HitFlash
	flash.cover($ModelController/Visuals)
	flash.add_pass(silhouette)
	equipment.flash = flash
	health.died.connect(_on_died, CONNECT_DEFERRED)
	health.changed.connect(func(current: int, _max_value: int) -> void: GameState.set_health_of(controls.slot, current))
	GameState.loaded.connect(_sync_health)
	GameState.max_health_changed.connect(_on_max_health_changed)
	_sync_health()
	var ward := GameState.ward_of(controls.slot)
	if ward > 0.0:
		GameState.set_ward_of(controls.slot, 0.0)
		health.ward(ward)
		Blessing.attach(self, health)
	targeting.target_changed.connect(func(target: Node3D) -> void: movement_state.blackboard.set_var(PlayerState.BB_TARGET, target))
	movement_state.initialize(self)
	movement_state.set_active(true)
	_default_trail = sword_trail.color_gradient
	equipment.weapon_changed.connect(func(_item: ItemData) -> void: _fit_sword_trail())
	_fit_sword_trail()


func _physics_process(delta: float) -> void:
	movement_state.update(delta)
	if is_on_floor():
		last_ground = global_position
	_watch_debug_values()


## La estela cubre la hoja del arma: del 35 % al extremo del eje más largo de sus mallas (Trail3D abre el ancho en Z local).
func _fit_sword_trail() -> void:
	sword_trail.color_gradient = equipment.weapon.trail if equipment.weapon and equipment.weapon.trail else _default_trail
	tip_trail.color_gradient = sword_trail.color_gradient
	var socket := equipment.weapon_socket
	var box := AABB()
	var found := false
	var to_socket := socket.global_transform.affine_inverse()
	for mesh: MeshInstance3D in socket.find_children("*", "MeshInstance3D", true, false):
		var part := (to_socket * mesh.global_transform) * mesh.get_aabb()
		box = box.merge(part) if found else part
		found = true
	if not found:
		return
	var axis := box.get_longest_axis_index()
	var near := box.get_center()
	var far := near
	near[axis] = box.position[axis]
	far[axis] = box.end[axis]
	if absf(near[axis]) > absf(far[axis]):
		var swap := near
		near = far
		far = swap
	near = near.lerp(far, 0.35)
	sword_trail.transform = socket.transform * Transform3D(Basis.looking_at(near - far, Vector3.UP if absf((near - far).normalized().y) < 0.9 else Vector3.RIGHT), (near + far) * 0.5)
	sword_trail.width = near.distance_to(far)
	tip_trail.position = socket.transform * far


func _process(_delta: float) -> void:
	var attack := attack_runner.current if attack_runner.is_active() else null
	var blade := attack != null and attack.trail and not attack.tip_trail
	var tip := attack != null and attack.trail and attack.tip_trail
	if blade != sword_trail.emitting:
		Feel.set_trail(sword_trail, blade)
	if tip != tip_trail.emitting:
		Feel.set_trail(tip_trail, tip)


## El ítem asignado al botón, si lo tiene y se puede usar ahora.
func usable_item(button: int) -> ItemData:
	var id := GameState.buttons_of(controls.slot)[button]
	var item := GameState.item_for(id)
	if item == null or item.behavior == null or not GameState.inventory.has(id):
		return null
	return item if item.behavior.can_use(make_item_context(), item) else null


## Alcance del gancho si está en un botón; cero si no.
func hook_reach() -> float:
	for id in GameState.buttons_of(controls.slot):
		var item := GameState.item_for(id)
		if item and item.behavior is HookBehavior and GameState.inventory.has(id):
			return (item.behavior as HookBehavior).reach
	return 0.0


func make_item_context() -> ItemUseContext:
	var ctx := ItemUseContext.new()
	ctx.user = self
	ctx.origin = equipment.weapon_socket.global_position if equipment.weapon_socket else global_position + Vector3.UP
	ctx.direction = aim.get_direction()
	ctx.inventory = GameState.inventory
	ctx.throw_to = aim.throw_point()
	return ctx


## Al cruzar a otra sala: camina solo hacia adentro mientras la cámara se desliza. Volando con el gancho no: el tirón
## termina al lado del poste.
func begin_room_transition(direction: Vector3, duration: float) -> void:
	if is_dead:
		return
	var state := movement_state.get_active_state() as PlayerState
	if state and state.blocks_room_transition():
		return
	movement_state.blackboard.set_var(PlayerState.BB_TRANSITION_DIR, direction)
	movement_state.blackboard.set_var(PlayerState.BB_TRANSITION_TIME, duration)
	movement_state.dispatch("transition")


## El bloque contra el que camina, si lo empuja de frente.
func block_ahead(direction: Vector3) -> PushBlock:
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var block := collision.get_collider() as PushBlock
		if block and direction.dot(-collision.get_normal()) > 0.7:
			return block
	return null


## Lo llama un Liftable al interactuar: lo levanta sobre la cabeza.
func lift(liftable: Liftable) -> void:
	movement_state.blackboard.set_var(PlayerState.BB_LIFTABLE, liftable)
	movement_state.dispatch("lift")


func is_spirit() -> bool:
	return movement_state.get_active_state() == $MovementState/Spirit


## Co-op (13.4): el espíritu vuelve con la vida que da el estado Spirit.
func revive() -> void:
	if not is_spirit():
		return
	health.heal($MovementState/Spirit.revive_health)
	movement_state.dispatch("revive")
	Feel.sfx(&"pickup", global_position)


func can_interact() -> bool:
	var state := movement_state.get_active_state() as PlayerState
	return state != null and state.can_interact


## Lo llaman cofres y recompensas después de GameState.give().
func play_item_get(item: ItemData, amount: int = 1) -> void:
	movement_state.blackboard.set_var(PlayerState.BB_GOT_ITEM, item)
	movement_state.blackboard.set_var(PlayerState.BB_GOT_AMOUNT, amount)
	movement_state.dispatch("item_get")


func deny_item(button: int) -> void:
	Feel.sfx(&"deny", global_position)
	item_denied.emit(button)


## Lo agarra `grip` (lo sigue hasta que se suelta o lo sueltan). No se puede rodando, muerto o ya agarrado.
func grab(grip: Node3D) -> bool:
	if is_dead or health.is_invulnerable() or is_grabbed():
		return false
	movement_state.blackboard.set_var(PlayerState.BB_GRABBED_BY, grip)
	movement_state.dispatch("grabbed")
	return is_grabbed()


func release() -> void:
	movement_state.blackboard.set_var(PlayerState.BB_GRABBED_BY, null)


## Sube o baja una escalera siguiendo path (puntos en el mundo); en los tramos verticales mira hacia face.
func climb(path: PackedVector3Array, face: Vector3) -> bool:
	if is_dead or is_climbing():
		return false
	movement_state.blackboard.set_var(PlayerState.BB_CLIMB_PATH, path)
	movement_state.blackboard.set_var(PlayerState.BB_CLIMB_FACE, face)
	movement_state.dispatch("climb")
	return is_climbing()


func is_climbing() -> bool:
	return movement_state.get_active_state() == $MovementState/Climbing


func is_grabbed() -> bool:
	return movement_state.get_active_state() == $MovementState/Grabbed


func is_blocking() -> bool:
	return movement_state.blackboard.get_var(PlayerState.BB_IS_BLOCKING, false)


## El ataque que toca según lo que tiene en la mano; cubriéndose con la espada, la estocada.
func current_attack(step := 0) -> AttackData:
	var melee := _melee()
	if melee == null:
		return null
	if is_blocking():
		return SWORD_STAB
	var chain := melee.chain()
	return chain[step % chain.size()]


func combo_length() -> int:
	var melee := _melee()
	return melee.chain().size() if melee else 1


## El giro cargado del arma en la mano (`great`: el grande, si lo tiene); null si no tiene o se está cubriendo.
func spin_attack(great := false) -> AttackData:
	var melee := _melee()
	if melee == null or is_blocking():
		return null
	return melee.great_spin if great and melee.great_spin else melee.spin


func _melee() -> MeleeBehavior:
	var weapon := equipment.weapon
	return weapon.behavior as MeleeBehavior if weapon else null


func _make_damage() -> DamageInfo:
	if equipment.weapon:
		return equipment.weapon.make_damage(self)
	return config.make_damage(self)


## La vida es global (GameState), no de la escena: al aparecer o cargar, la que tenía.
func _sync_health() -> void:
	health.restore(GameState.max_health, GameState.health_of(controls.slot))


## Un contenedor llena la vida de los vivos; el caído (Espíritu) sigue en 0 hasta que lo reviven.
func _on_max_health_changed(_value: int) -> void:
	if is_dead:
		health.restore(GameState.max_health, 0)
	else:
		health.reset(GameState.max_health)


## Diferido: el golpe llega en un callback de física y al lastimarse suelta lo que lleva (reparenta un cuerpo).
func _hurt() -> void:
	if not is_dead and not is_grabbed():
		movement_state.dispatch("hurt")


func _on_hit(info: DamageInfo) -> void:
	if not info.unavoidable and shield.stops(info):
		return
	var amount := maxi(1, roundi(info.amount * (1.0 - equipment.damage_reduction())))
	if not health.damage(amount, info.unavoidable):
		return
	Log.info(&"combat", "El player recibió", amount, "de daño de", info.source.name if info.source else "?", "· Vida:", health.current)
	movement_state.blackboard.set_var(PlayerState.BB_LAST_HIT, info)
	Feel.shake(Feel.settings.shake_take, Vector3.ZERO, controls.joypads)
	Feel.sfx(&"hurt", global_position)
	Feel.hit_stop([self, info.source], Feel.settings.hit_stop_take)
	if is_dead:
		Log.info(&"combat", "El player murió:", info.source.name if info.source else "?", "le sacó", amount, "con", health.max_health, "de vida máxima")
		return
	if not is_grabbed():
		_hurt.call_deferred()


func _on_hit_landed(target: Hurtbox) -> void:
	if target.surface == "none":
		return
	Feel.hit_stop([self, target.entity()], Feel.settings.hit_stop_give)
	Feel.shake(Feel.settings.shake_give, Vector3.ZERO, controls.joypads)
	Feel.sfx(StringName("hit_" + target.surface), target.global_position)
	if Feel.settings.sparks_on_hit:
		var away := target.global_position - global_position
		away.y = 0.0
		Feel.burst(equipment.weapon.hit_burst if equipment.weapon else &"sparks", target.global_position + Vector3.UP * 0.8, away.normalized() + Vector3.UP * 0.3)


func _on_died() -> void:
	movement_state.dispatch("die")


func _watch_debug_values() -> void:
	var debug: bool = DebugOverlay.visible
	if not debug:
		return
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
		var player := Players.lead()
		return player.health.current if player else 0)
	Performance.add_custom_monitor("epiphany/target_locked", func() -> int:
		var player := Players.lead()
		return 1 if player and player.targeting.current else 0)
