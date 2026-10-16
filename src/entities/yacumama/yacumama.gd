class_name Yacumama
extends Amaru
## Yacumama, la madre serpiente (jefa de D3). Asoma por uno de sus charcos, escupe y queda asomada un rato: asomada,
## todo rebota menos el gancho, que la arranca del charco y la tira al piso junto al player; ahí le pega la espada.
## Después vuelve reptando y se hunde. Con la mitad de la vida o menos, antes de escupir barre la sala con la cola
## desde su charco: pega a quien está en el piso, y se salta con la pluma.

@export var spits := 2
@export var spit_gap := 0.7
## Lo que queda asomada después de escupir: la ventana del gancho.
@export var exposed_time := 2.5
@export var yank_time := 0.45
## A qué distancia del player cae arrancada.
@export var yank_gap := 2.0
@export var tail_rise_time := 0.7
@export var sweep_time := 1.8
@export var sweep_damage := 2
## De `arena` a la pared: la cola llega hasta ahí.
@export var arena_wall := 1.0

@onready var tail: Node3D = %Tail
@onready var tail_length: float = (%TailModel as MeshInstance3D).get_aabb().size.z

var _sweeping := false
var _sweep_from := 0.0
var _swept := 0.0
var _sweep_hit: Array = []


func _ready() -> void:
	super()
	tail.hide()


func _physics_process(delta: float) -> void:
	super(delta)
	if _sweeping:
		_sweep(delta)


func _run() -> void:
	var turn := _turn
	while not is_dead and turn == _turn:
		await _dive()
		if turn != _turn:
			return
		if may_attack.is_valid() and not may_attack.call(self):
			await _wait(0.4)
			continue
		await _rise()
		if turn != _turn:
			return
		if raging():
			await _tail_sweep()
			if turn != _turn:
				return
		for i in spits:
			_spit()
			await _wait(spit_gap)
			if turn != _turn:
				return
		await _wait(exposed_time)
		if turn != _turn:
			return
		attack_finished.emit()


## Arrancada por el gancho: cae junto al player, queda tirada y vuelve a su charco.
func _yanked() -> void:
	_interrupt()
	var turn := _turn
	state = State.LUNGE
	var player := Players.nearest(global_position)
	var to := global_position
	if player:
		var away := (global_position - player.global_position) * Vector3(1, 0, 1)
		to = player.global_position + (away.normalized() if not away.is_zero_approx() else Vector3.FORWARD) * yank_gap
		to = Vector3(clampf(to.x, arena.position.x, arena.end.x), global_position.y, clampf(to.z, arena.position.y, arena.end.y))
		_face(player.global_position - global_position)
	_pose_flat()
	Feel.burst(&"splash", global_position + Vector3.UP * 0.2, Vector3.UP)
	Feel.sfx(&"splash", global_position)
	_tween_to(self, ^"global_position", to, yank_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await _wait(yank_time)
	if turn != _turn:
		return
	Feel.burst(&"dust", global_position + Vector3.UP * 0.1, Vector3.UP)
	Feel.sfx(&"boom", global_position)
	Feel.shake(0.3)
	await _lie()
	if turn != _turn:
		return
	await _crawl_back()
	if turn != _turn:
		return
	attack_finished.emit()
	_run()


func _tail_sweep() -> void:
	var player := Players.nearest(global_position)
	var toward := (player.global_position - global_position) if player else Vector3.FORWARD
	_sweep_from = atan2(-toward.x, -toward.z) + PI * 0.75
	tail.global_position = _pool.global_position + Vector3.DOWN * 0.6
	var reach := _to_wall(tail.global_position, Vector3.FORWARD.rotated(Vector3.UP, _sweep_from))
	tail.global_basis = Basis(Vector3.UP, _sweep_from) * Basis.from_scale(Vector3(1, 1, reach / tail_length))
	tail.show()
	Feel.burst(&"splash", tail.global_position + Vector3.UP * 0.7, Vector3.UP)
	Feel.sfx(&"rumble", tail.global_position)
	_tween_to(tail, ^"position:y", _pool.global_position.y + 0.25, tail_rise_time)
	await _wait(tail_rise_time)
	_swept = 0.0
	_sweep_hit.clear()
	_sweeping = true
	Feel.sfx(&"roll", global_position)
	await _wait(sweep_time)
	_sweeping = false
	_tween_to(tail, ^"position:y", _pool.global_position.y - 0.6, 0.3)
	await _wait(0.3)
	tail.hide()


## La cola gira una vuelta entera; le pega a quien está en el piso cuando pasa.
func _sweep(delta: float) -> void:
	var before := _swept
	_swept = minf(_swept + TAU * delta * pace / sweep_time, TAU)
	var pivot := tail.global_position
	var reach := _to_wall(pivot, Vector3.FORWARD.rotated(Vector3.UP, _sweep_from + _swept))
	tail.global_basis = Basis(Vector3.UP, _sweep_from + _swept) * Basis.from_scale(Vector3(1, 1, reach / tail_length))
	for player in Players.alive():
		if _sweep_hit.has(player) or not player.is_on_floor():
			continue
		var away: Vector3 = (player.global_position - pivot) * Vector3(1, 0, 1)
		if away.length() > reach + 0.4:
			continue
		var angle := fposmod(atan2(-away.x, -away.z) - _sweep_from, TAU)
		if angle < before or angle > _swept:
			continue
		_sweep_hit.append(player)
		var info := DamageInfo.make(sweep_damage, config.attack_knockback, self, DamageInfo.BLAST)
		info.team = config.team
		player.hurtbox.receive(info)


## Hasta la pared de la sala, sin pasar el largo de la cola.
func _to_wall(from: Vector3, direction: Vector3) -> float:
	var room := arena.grow(arena_wall)
	var reach := tail_length
	for axis in [0, 2]:
		var d: float = direction[axis]
		if absf(d) < 0.001:
			continue
		var low: float = room.position.x if axis == 0 else room.position.y
		var high: float = room.end.x if axis == 0 else room.end.y
		reach = minf(reach, maxf(((high if d > 0.0 else low) - from[axis]) / d, 0.5))
	return reach


func _interrupt() -> void:
	super()
	_sweeping = false
	tail.hide()


func _on_hit(info: DamageInfo) -> void:
	if is_dead or state == State.IDLE:
		return
	if info.element == Hook.ELEMENT and state in [State.RISE, State.AIM]:
		_yanked()
		return
	super(info)
