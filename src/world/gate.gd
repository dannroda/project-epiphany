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
@export var reveal_on_open := true
## Interruptores que, la primera vez que se activan, la muestran con la cámara aunque `reveal_on_open` esté apagado
## (la placa lejos de la reja; el ojo con tiempo de la misma sala no la pausa).
@export var reveal_from: Array[NodePath] = []
## Fondo del paso en el que está: la colisión lo cubre entero; la reja es una sola, en el medio.
@export var depth := 0.0

## 0 cerrada, 1 hundida `drop`: la anima el clip "open" de %Sink.
var openness := 0.0:
	set(value):
		openness = value
		position.y = _closed_y - drop * openness

var is_open := false
var _wiring: Wiring
var _closed_y := 0.0

@onready var sink: AnimationPlayer = %Sink


func _ready() -> void:
	_closed_y = position.y
	_fill_depth()
	if switches.is_empty():
		return
	for path in reveal_from:
		var switch := get_node(path)
		switch.activated.connect(func() -> void:
			if switch.is_node_ready() and not _wiring.revealed:
				_wiring.revealed = true
				TopDownCamera.reveal(self, open))
	_wiring = Wiring.create(self, switches, condition).drive(self, open, close)


func _fill_depth() -> void:
	if depth <= 0.0:
		return
	var box := $CollisionShape3D.shape.duplicate() as BoxShape3D
	box.size.z = depth
	$CollisionShape3D.shape = box


## Sin animación: ya estaba abierta al cargar la escena.
func open(animate := true) -> void:
	if is_open:
		return
	is_open = true
	$CollisionShape3D.set_deferred(&"disabled", true)
	if not animate:
		Clips.jump(sink, &"open", true)
		opened.emit()
		return
	Clips.run(sink, &"open", true, duration)
	Feel.sfx(&"secret", global_position)
	Feel.burst(&"dust", global_position + Vector3.UP * 0.2, Vector3.UP)
	opened.emit()


func close() -> void:
	if not is_open:
		return
	is_open = false
	$CollisionShape3D.set_deferred(&"disabled", false)
	Clips.run(sink, &"open", false, duration)
	Feel.sfx(&"click", global_position)
