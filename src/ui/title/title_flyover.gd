class_name TitleFlyover
extends Node3D
## El fondo del título: el overworld en vivo (sin jugador, HUD ni su cámara) cargado en segundo plano, con la cámara
## recorriendo las tomas de Shots como el video de antes (tools/title_flyover). Avisa con `ready_to_show` al cargar; corre aunque el título
## quede tapado por otra pantalla.

signal ready_to_show

const LEVEL := "res://levels/overworld.tscn"
## Lo que el título no usa del overworld.
const STRIP: Array[NodePath] = [^"Player", ^"HUD", ^"TopDownCamera"]

@export var sequence: PackedStringArray = ["Overview", "Templo", "Overview", "Laguna", "Overview", "Quenoa", "Overview", "Chullpa", "Overview", "Cumbre"]
@export var hold := 6.0
@export var overview_hold := 4.5
@export var travel := 3.5

## Ya cargó (o falló la carga): se puede mostrar.
var shown := false

@onready var _camera: Camera3D = $Camera3D
var _time := 0.0
var _loading := true


func _ready() -> void:
	_camera.make_current()
	# Sin ventana (tests, servidor) no hay fondo que mostrar.
	if DisplayServer.get_name() == "headless":
		_loading = false
		_show.call_deferred()
		return
	ResourceLoader.load_threaded_request(LEVEL)


func _process(delta: float) -> void:
	if _loading:
		_poll()
		return
	_time += delta
	_place(fmod(_time, _length()))


func _poll() -> void:
	match ResourceLoader.load_threaded_get_status(LEVEL):
		ResourceLoader.THREAD_LOAD_LOADED:
			_loading = false
			# Si SceneFlow ya está entrando al juego, el pedido es suyo: se usa sin sacárselo.
			var packed: PackedScene = load(LEVEL) if SceneFlow.traveling else ResourceLoader.load_threaded_get(LEVEL)
			var level := packed.instantiate()
			for path in STRIP:
				var node := level.get_node_or_null(path)
				if node:
					level.remove_child(node)
					node.free()
			add_child(level)
			for node in get_tree().get_nodes_in_group(ZoneVeil.GROUP):
				if level.is_ancestor_of(node):
					(node as Node3D).hide()
			_camera.make_current()
			_show()
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_loading = false
			_show()


func _show() -> void:
	shown = true
	ready_to_show.emit()


func _length() -> float:
	var total := 0.0
	for shot in sequence:
		total += (overview_hold if shot == "Overview" else hold) + travel
	return total


func _place(t: float) -> void:
	for i in sequence.size():
		var shot := get_node("Shots/" + sequence[i])
		var next := get_node("Shots/" + sequence[(i + 1) % sequence.size()])
		var span := overview_hold if sequence[i] == "Overview" else hold
		if t < span:
			_camera.global_transform = shot.get_node(^"From").global_transform.interpolate_with(shot.get_node(^"To").global_transform, t / span)
			return
		t -= span
		if t < travel:
			_camera.global_transform = shot.get_node(^"To").global_transform.interpolate_with(next.get_node(^"From").global_transform, smoothstep(0.0, 1.0, t / travel))
			return
		t -= travel
