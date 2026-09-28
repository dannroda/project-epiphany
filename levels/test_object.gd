class_name TestObject
extends RigidBody3D

@onready var mesh: MeshInstance3D = $MeshInstance3D
@export var default_color:Color = Color.AQUAMARINE
@export var selected_color:Color = Color.GREEN
@export var hit_color:Color = Color.RED

var selected:bool = false

var material:StandardMaterial3D
var _current_color:Color: 
	set(value):
		_current_color = value
		material.albedo_color = value


func _ready() -> void:
	material = StandardMaterial3D.new()
	_current_color = default_color
	mesh.set_surface_override_material(0, material)
	add_to_group("targetable")

func update_color(_color:Color = default_color):
	_current_color = _color
	
func deselect():
	update_color()
	selected = false

func select():
	update_color(selected_color)
	selected = true

func trigger_hit():
	var prev_color = _current_color
	update_color(hit_color)
	await get_tree().create_timer(1).timeout
	update_color(prev_color)
	
