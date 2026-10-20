class_name ArenaFight
extends Node3D
## Pelea de sub-jefe o jefe en una sala. Sus hijos ArenaFighter (WatcherEye, MummyGuard…) pelean dentro de ella:
## al entrar el player se cierran las puertas, la cámara los muestra a todos gritando con el nombre y arranca,
## con la barra del HUD. De a uno ataca por vez; cuando cae uno, los demás se apuran. Si el player sale de la sala,
## la pelea vuelve a empezar; en el overworld (`area`), una vez arrancada sigue aunque se aleje, y también arranca si
## le pegan desde lejos (una flecha). Hace de interruptor (`active`/`activated`) para lo que se abre al ganar; con flag,
## ganada queda ganada.

signal activated
signal bar_changed

@export var room: Room
## Fuera de las mazmorras (overworld), en vez de `room`.
@export var area: ArenaArea
@export var flag: StringName:
	set(value):
		flag = value
		update_configuration_warnings()
@export var display_name := ""
## Se cierran durante la pelea y se abren al ganar.
@export var doors: Array[Door] = []
## En el overworld, lo que encierra la pelea en vez de las puertas (FireRing).
@export var barrier: FireRing
## Aparece al ganar (el contenedor de corazón): queda fuera del árbol hasta entonces; tomado, no vuelve.
@export var reward: Pickup
@export var reward_flag: StringName
## Monstruos que acompañan al jefe: aparecen al arrancar la pelea, copias nuevas de los puestos a mano (con sus overrides)
## cada vez, y también hay que vencerlos para ganar.
@export var escorts: Array[Enemy] = []
@export var arena_margin := 1.5
@export var close_delay := 0.6
@export var intro_hold := 1.6
## Lo que se apuran los que quedan al caer uno.
@export var enrage_pace := 1.4
## Revancha (templo, 11.182): arrancan con media vida, así ya pelean como con media vida, y si son varios, apurados.
@export var rematch := false

var active := false
var started := false
var in_intro := false
var _fighters: Array[ArenaFighter] = []
var _attacker: ArenaFighter
var _persistent: PersistentFlag
var _escort_scenes: Array[PackedScene] = []
var _escort_transforms: Array[Transform3D] = []
var _escorts_alive: Array[Enemy] = []


## Antes de que entren al árbol: se guardan tal como están en el nivel (con los overrides de sus hijos) y salen de él.
func _enter_tree() -> void:
	if not _escort_scenes.is_empty():
		return
	for escort in escorts:
		var scene := PackedScene.new()
		scene.pack(escort)
		_escort_scenes.append(scene)
		_escort_transforms.append(global_transform * _transform_to(escort))
		escort.get_parent().remove_child(escort)
		escort.queue_free()


func _transform_to(node: Node3D) -> Transform3D:
	var local := Transform3D.IDENTITY
	while node and node != self:
		local = node.transform * local
		node = node.get_parent() as Node3D
	return local


func _ready() -> void:
	for child in get_children():
		if child is ArenaFighter:
			_fighters.append(child)
	if reward:
		remove_child(reward)
	_persistent = $PersistentFlag
	_persistent.flag = flag
	if _persistent.value == true:
		_already_won()
		return
	var zone: Node3D = room if room else area
	var bounds: Rect2 = zone.bounds().grow(-arena_margin)
	for fighter in _fighters:
		fighter.arena = bounds
		fighter.may_attack = _may_attack
		fighter.peers = _fighters
		fighter.attack_finished.connect(_on_attack_finished.bind(fighter))
		fighter.defeated.connect(_on_defeated)
		fighter.health_changed.connect(bar_changed.emit)
	zone.player_entered.connect(func(_zone: Node3D) -> void: _begin())
	if room:
		room.player_left.connect(func(_zone: Node3D) -> void: _reset())
	else:
		for fighter in _fighters:
			if fighter.hurtbox:
				fighter.hurtbox.hit.connect(func(_info: DamageInfo) -> void: _begin())


func _get_configuration_warnings() -> PackedStringArray:
	return PersistentFlag.warnings_for(flag, true, self)


func _begin() -> void:
	if started or active:
		return
	started = true
	await Tweens.wait(self, close_delay)
	if not started or not is_inside_tree():
		return
	for door in doors:
		door.close()
	if barrier:
		barrier.close()
	in_intro = true
	Music.hold_boss(self)
	var seen_key: Variant = flag if flag != &"" else get_path()
	await TopDownCamera.reveal(self, _awaken, intro_hold, rematch or SceneFlow.session.seen_boss_intros.has(seen_key))
	SceneFlow.session.seen_boss_intros[seen_key] = true
	in_intro = false
	if not started or not is_inside_tree():
		return
	Hud.events.boss_shown.emit(BossBar.new(display_name, bar_changed, bar_fraction))
	_spawn_escorts()
	for fighter in _fighters:
		fighter.start()
		if rematch:
			fighter.health.restore(fighter.health.max_health, ceili(fighter.health.max_health / 2.0))
			if _fighters.size() > 1:
				fighter.pace = enrage_pace
	bar_changed.emit()


func _awaken() -> void:
	Hud.events.area_announced.emit(tr(display_name))
	Feel.sfx(&"rumble", _fighters[0].body.global_position, true)
	Feel.shake(0.35)
	for fighter in _fighters:
		fighter.roar()


## Adónde mira la cámara en la presentación: al medio de los que pelean, así se ven todos gritando.
func reveal_point() -> Vector3:
	var sum := Vector3.ZERO
	for fighter in _fighters:
		sum += fighter.body.global_position
	return sum / _fighters.size()


## Si son varios, la cámara se acerca menos para que entren todos.
func reveal_zoom(zoom: float) -> float:
	return zoom if _fighters.size() < 2 else 1.0


## El player salió (cayó por un hueco): todo como al llegar.
func _reset() -> void:
	if not started or active:
		return
	started = false
	_attacker = null
	Music.release_boss(self)
	Hud.events.boss_hidden.emit()
	for fighter in _fighters:
		fighter.reset()
	_clear_escorts()
	for door in doors:
		door.open(false)
	if barrier:
		barrier.open()


func _may_attack(fighter: ArenaFighter) -> bool:
	if is_instance_valid(_attacker) and _attacker != fighter and not _attacker.is_dead:
		return false
	_attacker = fighter
	return true


func _on_attack_finished(fighter: ArenaFighter) -> void:
	if _attacker == fighter:
		_attacker = null


func _spawn_escorts() -> void:
	_clear_escorts()
	for i in _escort_scenes.size():
		var escort := _escort_scenes[i].instantiate() as Enemy
		add_child(escort)
		escort.global_transform = _escort_transforms[i]
		escort.defeated.connect(func(_who: Enemy) -> void: _on_defeated(null))
		_escorts_alive.append(escort)
		Feel.burst(&"dust", escort.global_position, Vector3.UP)


func _clear_escorts() -> void:
	for escort in _escorts_alive:
		if is_instance_valid(escort):
			escort.queue_free()
	_escorts_alive.clear()


func _on_defeated(_fighter: Node3D) -> void:
	bar_changed.emit()
	var left := _fighters.filter(func(fighter: ArenaFighter) -> bool: return not fighter.is_dead)
	for fighter in left:
		fighter.pace = enrage_pace
	var escorts_left := _escorts_alive.any(func(escort: Enemy) -> bool: return is_instance_valid(escort) and not escort.is_dead)
	if left.is_empty() and not escorts_left and started:
		await Tweens.wait(self, 1.2)
		_win(true)


func _win(announce: bool) -> void:
	active = true
	started = false
	_persistent.value = true
	Music.release_boss(self)
	Hud.events.boss_hidden.emit()
	for door in doors:
		door.open()
	if barrier:
		barrier.open()
	_show_reward()
	if announce:
		Feel.sfx(&"secret", global_position)
		SaveManager.autosave()
	activated.emit()


func _already_won() -> void:
	active = true
	for fighter in _fighters:
		fighter.queue_free()
	_show_reward()


func _show_reward() -> void:
	if reward:
		Pickup.offer_once(reward, reward_flag, self)


## Barra del HUD: la vida que les queda a todos.
func bar_fraction() -> float:
	var total := 0
	var left := 0
	for fighter in _fighters:
		total += ceili(fighter.health.max_health / 2.0) if rematch else fighter.health.max_health
		left += maxi(fighter.health.current, 0)
	return float(left) / maxf(total, 1)


func _exit_tree() -> void:
	if reward and not reward.is_inside_tree():
		reward.queue_free()
