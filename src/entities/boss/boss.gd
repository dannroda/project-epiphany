@tool
class_name Boss
extends Node3D
## El Ojo con manos (gdd §9). Sin esqueleto: el ojo gira entero hacia lo que mira, los párpados de hierro se abren
## rotando en X y las manos flotan sueltas (vuelven a su reposo, al lado del cuerpo).

const LID_OPEN_ANGLE := 70.0

## 0 cerrado, 1 abierto.
@export_range(0.0, 1.0) var eye_open := 0.0:
	set(value):
		eye_open = value
		if is_inside_tree():
			_apply_lids()

@onready var body: Node3D = $Body
@onready var eye: Node3D = %Eye
@onready var orb_muzzle: Marker3D = %OrbMuzzle
@onready var hand_left: BossHand = $HandLeft
@onready var hand_right: BossHand = $HandRight


func _ready() -> void:
	_apply_lids()
	if not Engine.is_editor_hint():
		for hand in [hand_left, hand_right]:
			hand.global_position = hand_rest(hand).global_position


func look_at_point(point: Vector3) -> void:
	eye.look_at(point, Vector3.UP, true)


func hand_rest(hand: BossHand) -> Marker3D:
	return %HandRestLeft if hand == hand_left else %HandRestRight


func _apply_lids() -> void:
	%UpperLid.rotation.x = deg_to_rad(-LID_OPEN_ANGLE * eye_open)
	%LowerLid.rotation.x = deg_to_rad(LID_OPEN_ANGLE * eye_open)
