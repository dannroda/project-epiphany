class_name FireRing
extends Node3D
## Anillo de llamas que encierra una pelea del overworld (ArenaFight.barrier): se cierra cuando hay un player adentro y
## ninguno sobre la pared, y se abre al terminar. La pared es el mismo cilindro de las llamas.

@export var fade_time := 0.6

var radius := 0.0
var closed := false
var _closing := false
## 0 apagado y escondido, 1 entero: lo anima el clip "close" de %Fade.
var reveal := 0.0:
	set(value):
		reveal = value
		(flames.material_override as ShaderMaterial).set_shader_parameter(&"reveal", value)
		flames.visible = value > 0.0

@onready var flames: MeshInstance3D = %Flames
@onready var wall: CollisionShape3D = %Wall


func _ready() -> void:
	var mesh := flames.mesh as CylinderMesh
	radius = mesh.top_radius
	var shape := mesh.create_trimesh_shape()
	shape.backface_collision = true
	wall.shape = shape
	wall.disabled = true
	flames.hide()
	set_physics_process(false)


func close() -> void:
	if closed:
		return
	_closing = true
	set_physics_process(true)


func open() -> void:
	_closing = false
	set_physics_process(false)
	if not closed:
		return
	closed = false
	wall.set_deferred(&"disabled", true)
	Clips.run(%Fade, &"close", false, fade_time)


func _physics_process(_delta: float) -> void:
	var inside := false
	for player: PlayerCharacter in Players.all:
		var distance := Vector2(player.global_position.x - global_position.x, player.global_position.z - global_position.z).length()
		if absf(distance - radius) < 1.0:
			return
		inside = inside or distance < radius
	if not inside:
		return
	_closing = false
	set_physics_process(false)
	closed = true
	wall.set_deferred(&"disabled", false)
	Clips.run(%Fade, &"close", true, fade_time)
	Feel.sfx(&"rumble", global_position)
