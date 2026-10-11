class_name Gate
extends StaticBody3D
## Reja que se hunde en el piso al abrirse (la abre un interruptor, un cristal, un enemigo vencido…).

signal opened

@export var drop := 2.3
@export var duration := 0.6
## Opcional: interruptores que la abren (si no, la abre un script con open()).
@export var switches: Array[NodePath] = []
@export var condition: Wiring.Condition = Wiring.Condition.ALL
## Si es false, se vuelve a levantar cuando la condición deja de cumplirse.
@export var stays_open := true
## La primera vez que la abren sus interruptores, el juego se pausa y la cámara la muestra.
@export var reveal_on_open := false
## Fondo del paso en el que está: con más de 0, una reja en cada cara del muro.
@export var depth := 0.0

var is_open := false
var _wiring: Wiring
var _closed_y := 0.0
var _tween: Tween
var _revealed := false


func _ready() -> void:
	_closed_y = position.y
	_fill_depth()
	if switches.is_empty():
		return
	_wiring = Wiring.create(self, switches, condition)
	_wiring.changed.connect(func(satisfied: bool) -> void:
		if satisfied and reveal_on_open and not _revealed:
			_revealed = true
			TopDownCamera.reveal(self, open)
		elif satisfied:
			open()
		elif not stays_open:
			close())
	_wiring.settled.connect(func(satisfied: bool) -> void:
		if satisfied:
			open(false))


func _fill_depth() -> void:
	if depth <= 0.0:
		return
	var inset := depth / 2.0 - 0.15
	$Model.position.z = inset
	$Back.position.z = -inset
	$Back.show()
	var box := $CollisionShape3D.shape.duplicate() as BoxShape3D
	box.size.z = depth
	$CollisionShape3D.shape = box


## Sin animación: ya estaba abierta al cargar la escena.
func open(animate := true) -> void:
	if is_open:
		return
	is_open = true
	$CollisionShape3D.set_deferred(&"disabled", true)
	if _tween:
		_tween.kill()
	if not animate:
		position.y = _closed_y - drop
		opened.emit()
		return
	_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_property(self, "position:y", _closed_y - drop, duration)
	Feel.sfx(&"secret", global_position)
	Feel.burst(&"dust", global_position + Vector3.UP * 0.2, Vector3.UP)
	opened.emit()


func close() -> void:
	if not is_open:
		return
	is_open = false
	$CollisionShape3D.set_deferred(&"disabled", false)
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "position:y", _closed_y, duration)
	Feel.sfx(&"click", global_position)
