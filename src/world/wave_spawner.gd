class_name WaveSpawner
extends Node3D
## Oleadas de una sala: empiezan al entrar el player y mantienen cerradas sus persianas hasta vencer la última.
## Cada hijo directo es una oleada; sus hijos `WaveSpawn` dicen qué enemigo aparece y dónde: cualquier Node3D con
## `defeated` e `is_dead` (Enemy, Turret, o un sub-jefe en versión mini).
## Hace de interruptor (`active`/`activated`) para lo que se abre al ganar. Con flag, ganada queda ganada.

signal activated

const GROUP := &"wave_spawners"

@export var room: Room
@export var flag: StringName:
	set(value):
		flag = value
		update_configuration_warnings()
@export var wave_delay := 1.0
## Puertas que no son persianas de la sala: se cierran durante las oleadas y se abren al ganar.
@export var doors: Array[Door] = []

var active := false
## Hay oleadas en curso: la sala no abre sus persianas.
var running := false
var wave := -1
var _alive: Array[Node3D] = []
var _persistent: PersistentFlag


func _ready() -> void:
	add_to_group(GROUP)
	if flag != &"":
		_persistent = $PersistentFlag
		_persistent.flag = flag
		_persistent.changed.connect(func(value: Variant) -> void:
			if value == true and not active:
				_win(false))
		if _persistent.value == true:
			_win(false)
	if room:
		room.player_entered.connect(func(_room: Room) -> void: start())


func _get_configuration_warnings() -> PackedStringArray:
	return PersistentFlag.warnings_for(flag, true, self)


func waves() -> Array[Node]:
	return get_children().filter(func(child: Node) -> bool: return not child is PersistentFlag)


func start() -> void:
	if active or running:
		return
	running = true
	wave = -1
	for door in doors:
		door.close()
	_next_wave()


## Un enemigo por cuadro: instanciar varios juntos daba un tirón de ~20 ms.
func _next_wave() -> void:
	wave += 1
	_alive.clear()
	for spawn in waves()[wave].get_children():
		if not spawn is WaveSpawn or (spawn as WaveSpawn).enemy == null:
			continue
		if not _alive.is_empty():
			await get_tree().process_frame
			if not is_inside_tree():
				return
		var enemy := (spawn as WaveSpawn).enemy.instantiate() as Node3D
		enemy.position = (get_parent() as Node3D).to_local((spawn as WaveSpawn).global_position)
		get_parent().add_child(enemy)
		if enemy.has_signal(&"attack_finished"):
			_unleash(enemy)
		_alive.append(enemy)
		enemy.connect(&"defeated", _on_defeated)
		Feel.burst(&"dust", enemy.global_position, Vector3.UP)
	Log.info(&"world", name, "oleada", wave + 1, "de", waves().size())


## Un sub-jefe (los peleadores de ArenaFight) en una oleada: pelea solo, dentro de la sala.
func _unleash(fighter: Node3D) -> void:
	fighter.arena = room.bounds().grow(-1.5) if room else Rect2(Vector2(fighter.global_position.x, fighter.global_position.z), Vector2.ZERO).grow(6.0)
	fighter.may_attack = func(_who: Node3D) -> bool: return true
	fighter.peers = [fighter]
	fighter.start.call_deferred()


func _on_defeated(_enemy: Node3D) -> void:
	if _alive.any(func(enemy: Variant) -> bool: return is_instance_valid(enemy) and not enemy.is_dead):
		return
	if wave + 1 < waves().size():
		create_tween().tween_callback(_next_wave).set_delay(wave_delay)
	else:
		_win(true)


func _win(announce: bool) -> void:
	running = false
	active = true
	if _persistent:
		_persistent.value = true
	for door in doors:
		door.open()
	if announce:
		Feel.sfx(&"secret", global_position)
	activated.emit()
