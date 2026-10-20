extends PlayerState

## Qué tan rápido se frena el paso del golpe.
@export var lunge_damping := 12.0
## Segundos después de que un golpe termina o se corta en los que volver a apretar sigue el combo (tajo, revés,
## estocada); después vuelve a empezar por el tajo.
@export var combo_window := 0.45
## El rayo de espada (11.34 paso 5, se aprende en la piedra de la Cumbre): sale de cada golpe con la vida llena. Vacío
## en los estados que no lo tiran.
@export var beam: PackedScene

const BEAM_LEARNED := &"ow_tech_beam"

## El golpe del combo que está sonando (0 = el primero).
var step := 0
var _attack: AttackData
var _chain_until := -1.0
var _beam_pending := false


func _setup() -> void:
	(get_parent() as LimboHSM).active_state_changed.connect(_on_state_changed)


## Rodar, recibir un golpe o cualquier otra cosa que no sea quedarse o caminar corta el combo.
func _on_state_changed(current: LimboState, _previous: LimboState) -> void:
	if current != null and current != self and current.name not in [&"Idle", &"Moving"]:
		_chain_until = -1.0


func _enter() -> void:
	var observer: AnimationNodeObserver = player.anim_tree.get(&"parameters/Attack/observer")
	if not observer.fade_out_started.is_connected(_on_attack_finished):
		observer.fade_out_started.connect(_on_attack_finished)

	var chained := _now() <= _chain_until and not player.is_blocking()
	step = (step + 1) % player.combo_length() if chained else 0
	_chain_until = -1.0
	_attack = _pick_attack()
	_face_attack_direction()
	_beam_pending = beam != null and _attack != null and _attack != player.SWORD_STAB and player.health.current >= player.health.max_health and GameState.get_flag(BEAM_LEARNED)
	var forward := player.model.global_basis.z
	forward.y = 0.0
	forward = forward.normalized() * (_attack.lunge if _attack else 0.0)
	player.velocity.x = forward.x
	player.velocity.z = forward.z

	player.anim_tree.set(&"parameters/AttackType/transition_request", _attack.tree_state if _attack else &"Slash")
	player.anim_tree.set(&"parameters/Attack/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	if _attack and player.anim_player.has_animation(_attack.animation):
		player.attack_runner.start(_attack, player.anim_player.get_animation(_attack.animation).length)


func _update(delta: float) -> void:
	var damping := exp(-lunge_damping * delta)
	player.velocity.x *= damping
	player.velocity.z *= damping
	player.move_and_slide()
	if _beam_pending and player.attack_runner.progress() >= _attack.active_from:
		_beam_pending = false
		_fire_beam()
	if not can_cancel():
		return
	var input_dir: Vector2 = blackboard.get_var(BB_INPUT_DIR, Vector2.ZERO)
	if input_dir or (player.is_blocking() and _attack != player.SWORD_STAB):
		dispatch("finished")


func _exit() -> void:
	if _attack != player.SWORD_STAB and can_cancel():
		_chain_until = _now() + combo_window
	player.attack_runner.stop()


func _fire_beam() -> void:
	var forward := player.model.global_basis.z * Vector3(1, 0, 1)
	if forward.is_zero_approx():
		return
	forward = forward.normalized()
	var shot := beam.instantiate() as SwordBeam
	shot.shooter = player
	shot.team = player.hurtbox.team
	shot.damage_factory = func() -> DamageInfo: return DamageInfo.make(1, 2.0, player)
	Spawns.root(player).add_child(shot)
	var from := player.global_position + Vector3.UP * 1.0 + forward * 0.6
	shot.global_transform = Transform3D(Basis.looking_at(forward), from)
	Feel.sfx(&"reflect", from)


func _pick_attack() -> AttackData:
	return player.current_attack(step)


## En tiempo de juego (cuadros de física), no de reloj.
func _now() -> float:
	return float(Engine.get_physics_frames()) / Engine.physics_ticks_per_second


func can_cancel() -> bool:
	return _attack == null or player.attack_runner.progress() >= _attack.cancel_from


## Con objetivo fijado mira al objetivo; si no, hacia donde apunta el stick.
func _face_attack_direction() -> void:
	var direction := Vector3.ZERO
	var target := player.targeting.current
	if target and is_instance_valid(target):
		direction = target.global_position - player.global_position
	else:
		var input: Vector2 = blackboard.get_var(BB_INPUT_DIR, Vector2.ZERO)
		direction = Vector3(input.x, 0.0, input.y)
	direction.y = 0.0
	if not direction.is_zero_approx():
		player.model.look_at(player.model.global_position - direction, Vector3.UP)


func _on_attack_finished() -> void:
	if is_active():
		dispatch("finished")
