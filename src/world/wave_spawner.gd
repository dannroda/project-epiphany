class_name WaveSpawner
extends Node3D
## Oleadas de una sala: empiezan al entrar el player y mantienen cerradas sus persianas hasta vencer la última.
## Cada hijo directo es una oleada; sus hijos `WaveSpawn` dicen qué enemigo aparece y dónde.
## Hace de interruptor (`active`/`activated`) para lo que se abre al ganar. Con flag, ganada queda ganada.

signal activated

@export var room: Room
@export var flag: StringName:
	set(value):
		flag = value
		update_configuration_warnings()
@export var wave_delay := 1.0

var active := false
## Hay oleadas en curso: la sala no abre sus persianas.
var running := false
var wave := -1
var _alive: Array[Enemy] = []
var _persistent: PersistentFlag


func _ready() -> void:
	add_to_group(&"wave_spawners")
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
	return PersistentFlag.warnings_for(flag, true)


func waves() -> Array[Node]:
	return get_children().filter(func(child: Node) -> bool: return not child is PersistentFlag)


func start() -> void:
	if active or running:
		return
	running = true
	wave = -1
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
		var enemy := (spawn as WaveSpawn).enemy.instantiate() as Enemy
		enemy.position = (spawn as WaveSpawn).global_position
		get_parent().add_child(enemy)
		_alive.append(enemy)
		enemy.defeated.connect(_on_defeated)
		Feel.burst(&"dust", enemy.global_position, Vector3.UP)
	Log.info(&"world", name, "oleada", wave + 1, "de", waves().size())


func _on_defeated(_enemy: Enemy) -> void:
	if _alive.any(func(enemy: Variant) -> bool: return is_instance_valid(enemy) and not enemy.is_dead):
		return
	if wave + 1 < waves().size():
		await get_tree().create_timer(wave_delay).timeout
		_next_wave()
	else:
		_win(true)


func _win(announce: bool) -> void:
	running = false
	active = true
	if _persistent:
		_persistent.value = true
	if announce:
		Feel.sfx(&"secret", global_position)
	activated.emit()
