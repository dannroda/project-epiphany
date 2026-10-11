extends Node3D
## Escena de prueba del personaje toon (12.12): ←/→ cambian de animación, ↑/↓ giran la cámara, 4 alterna el toon.

const LIBS := ["General", "MovementBasic", "CombatMelee"]
## El pasto de la paleta (UV de Godot), para que el piso también pase por el toon.
const GROUND_UV := Vector2(0.0625, 0.08)
const PALETTE := preload("res://data/kits/materials/epiphany.tres")

var _anims: Array[String] = []
var _index := 0
var _player := AnimationPlayer.new()

@onready var _rig: Node3D = $Model/Rig_Medium
@onready var _pivot: Node3D = $CameraPivot
@onready var _camera: Camera3D = $CameraPivot/Camera3D
@onready var _label: Label = $Hud/Label
@onready var _ground: MeshInstance3D = $Ground


func _ready() -> void:
	_rig.add_child(_player)
	_player.root_node = ^".."
	for lib_name: String in LIBS:
		var lib: AnimationLibrary = load("res://player/animation/libs/%s.res" % lib_name)
		_player.add_animation_library(lib_name, lib)
		for anim in lib.get_animation_list():
			if not (anim.contains("T-Pose") or anim.ends_with("_Pose")):
				_anims.append("%s/%s" % [lib_name, anim])
	_player.animation_finished.connect(func(_name: StringName) -> void: _play(_index))
	_ground.mesh = _ground_mesh()
	_camera.look_at(Vector3(0, 1.0, 0))
	ToonToggle.set_enabled(true)
	_play(maxi(_anims.find("General/Idle_A"), 0))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_right"):
		_play(_index + 1)
	elif event.is_action_pressed(&"ui_left"):
		_play(_index - 1)


func _process(delta: float) -> void:
	_pivot.rotate_y(Input.get_axis(&"ui_down", &"ui_up") * 1.5 * delta)


func _play(index: int) -> void:
	_index = wrapi(index, 0, _anims.size())
	_player.play(_anims[_index])
	_label.text = "%s  (%d/%d)\n←/→ animación · ↑/↓ girar · 4 toon" % [_anims[_index], _index + 1, _anims.size()]


func _ground_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	st.set_uv(GROUND_UV)
	for corner in [Vector3(-8, 0, -8), Vector3(8, 0, -8), Vector3(8, 0, 8), Vector3(-8, 0, -8), Vector3(8, 0, 8), Vector3(-8, 0, 8)]:
		st.add_vertex(corner)
	var mesh := st.commit()
	mesh.surface_set_material(0, PALETTE)
	return mesh
