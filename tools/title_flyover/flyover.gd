extends Node3D
## Graba el paneo del overworld que va de fondo en la pantalla de título: tomas de distintos sectores intercaladas con la
## vista general. Cada toma de Shots tiene From y To (la cámara se desliza de uno a otro en hold segundos) y entre
## tomas la cámara viaja suave en travel segundos; la última vuelve a la primera, así el video da la vuelta sin salto.
## godot --path . --write-movie debug/tmp/<carpeta>/flyover.avi --fixed-fps 30 --resolution 640x360 res://tools/title_flyover/flyover.tscn
## ffmpeg -i flyover.avi -vf "scale=960:540,gblur=sigma=4" -r 24 -c:v libtheora -q:v 4 -an assets/ui/title/flyover.ogv

@export var sequence: PackedStringArray = ["Overview", "Templo", "Overview", "Laguna", "Overview", "Quenoa", "Overview", "Chullpa", "Overview", "Cumbre"]
@export var hold := 6.0
@export var overview_hold := 4.5
@export var travel := 3.5

@onready var _camera: Camera3D = $Camera3D
var _time := 0.0


func _ready() -> void:
	_camera.make_current()


func _process(delta: float) -> void:
	for node in get_tree().root.find_children("*", "CanvasLayer", true, false):
		node.hide()
	for node in get_tree().get_nodes_in_group(&"zone_veil"):
		node.hide()
	for node in get_tree().get_nodes_in_group(&"player"):
		node.hide()
	var t := _time
	_time += delta
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
	get_tree().quit()
