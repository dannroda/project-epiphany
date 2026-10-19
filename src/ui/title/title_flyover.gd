class_name TitleFlyover
extends Node3D
## El fondo del título: el overworld en vivo (sin jugador, HUD ni su cámara) cargado en segundo plano, con la cámara
## recorriendo las tomas del clip "flight" de $Flight, como el video de antes. Avisa con `ready_to_show` al cargar;
## corre aunque el título quede tapado por otra pantalla.

signal ready_to_show

const LEVEL := "res://levels/overworld.tscn"
## Lo que el título no usa del overworld.
const STRIP: Array[NodePath] = [^"Player", ^"HUD", ^"TopDownCamera"]

## Ya cargó (o falló la carga): se puede mostrar.
var shown := false

@onready var _camera: Camera3D = $Camera3D
@onready var _flight: AnimationPlayer = $Flight
var _loading := true


func _ready() -> void:
	_camera.make_current()
	# Sin ventana (tests, servidor) no hay fondo que mostrar.
	if DisplayServer.get_name() == "headless":
		_loading = false
		_show.call_deferred()
		return
	ResourceLoader.load_threaded_request(LEVEL)


func _process(_delta: float) -> void:
	if _loading:
		_poll()


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
	_flight.play(&"flight")
	ready_to_show.emit()
