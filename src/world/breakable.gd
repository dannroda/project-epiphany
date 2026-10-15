class_name Breakable
extends Node3D
## Vasijas, pasto y plantas: se rompen con cualquier golpe (espada, bomba), sueltan según su DropTable y reaparecen al recargar.
## SHATTER: desaparece en el acto. CUT: la mata salta girando y se achica. FELL: cae del lado contrario al golpe, rebota y se hunde.
## Si tiene un "Stump" (oculto), queda a la vista hasta recargar. El choque de las sandalias sacude los árboles (FELL) sin voltearlos.

enum Break { SHATTER, CUT, FELL }

@export var drops: DropTable
@export var burst: StringName = &"shards"
@export var sound: StringName = &"break"
@export var drop_height := 0.0
@export var break_style := Break.SHATTER
@export var cut_time := 0.3
@export var fall_time := 0.55
@export var sink_time := 0.4
## Solo la rompe un golpe fuerte (martillo); lo demás rebota.
@export var needs_strong := false

@onready var hurtbox: Hurtbox = $Hurtbox

var broken := false
var _shaking := false


func _ready() -> void:
	hurtbox.hit.connect(_on_hit)


func _on_hit(info: DamageInfo) -> void:
	if info.element == &"dash" and break_style == Break.FELL:
		shake()
		return
	if needs_strong and not info.strong:
		Feel.sfx(&"block", global_position)
		return
	smash(info.source.global_position if is_instance_valid(info.source) else Vector3.INF)


func shake() -> void:
	var model := get_node_or_null(^"Model") as Node3D
	if broken or model == null or _shaking:
		return
	_shaking = true
	Feel.burst(&"leaves", global_position + Vector3.UP * 2.4, Vector3.DOWN)
	Feel.sfx(&"hit", global_position)
	var rest := model.position
	var tween := create_tween()
	for offset: float in [0.12, -0.1, 0.06, -0.03, 0.0]:
		tween.tween_property(model, ^"position:x", rest.x + offset, 0.06)
	tween.tween_callback(func() -> void: _shaking = false)


func smash(from := Vector3.INF) -> void:
	if broken:
		return
	broken = true
	Feel.burst(burst, global_position + Vector3.UP * 0.3, Vector3.UP)
	Feel.sfx(sound, global_position)
	if drops:
		drops.drop_at.call_deferred(global_position + Vector3.UP * drop_height, get_parent())
	if break_style == Break.SHATTER:
		queue_free()
		return
	hurtbox.set_deferred(&"monitorable", false)
	var body := get_node_or_null(^"Body") as CollisionObject3D
	if body:
		body.process_mode = Node.PROCESS_MODE_DISABLED
	var stump := get_node_or_null(^"Stump") as Node3D
	if stump:
		stump.visible = true
	var leaves := get_node_or_null(^"Leaves")
	if leaves:
		leaves.queue_free()
	var model := $Model as Node3D
	if break_style == Break.CUT:
		_cut(model, stump)
	else:
		_fell(model, stump, from)


func _cut(model: Node3D, stump: Node3D) -> void:
	var tween := create_tween().set_parallel()
	tween.tween_property(model, ^"position:y", model.position.y + 0.5, cut_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(model, ^"rotation:y", model.rotation.y + PI, cut_time)
	tween.tween_property(model, ^"scale", Vector3.ONE * 0.05, cut_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(_finish.bind(model, stump))


func _fell(model: Node3D, stump: Node3D, from: Vector3) -> void:
	var away := global_position - from if from != Vector3.INF else Vector3(randf_range(-1, 1), 0, 1)
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else Vector3.BACK
	var axis := Vector3.UP.cross(away).normalized()
	var start := model.global_basis
	var tilt := func(angle: float) -> void: model.global_basis = Basis(axis, angle) * start
	var tween := create_tween()
	tween.tween_method(tilt, 0.0, deg_to_rad(85.0), fall_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		Feel.burst(&"dust", global_position + away * 1.2, Vector3.UP)
		Feel.sfx(&"hit", global_position))
	tween.tween_method(tilt, deg_to_rad(85.0), deg_to_rad(75.0), 0.1).set_ease(Tween.EASE_OUT)
	tween.tween_method(tilt, deg_to_rad(75.0), deg_to_rad(88.0), 0.15).set_ease(Tween.EASE_IN)
	tween.tween_interval(0.2)
	tween.tween_property(model, ^"position:y", model.position.y - 0.6, sink_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(model, ^"scale", Vector3.ONE * 0.6, sink_time)
	tween.tween_callback(_finish.bind(model, stump))


func _finish(model: Node3D, stump: Node3D) -> void:
	if stump:
		model.queue_free()
		for child in get_children():
			if child != stump:
				child.queue_free()
	else:
		queue_free()
