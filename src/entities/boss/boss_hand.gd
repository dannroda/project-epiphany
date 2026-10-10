@tool
class_name BossHand
extends Node3D
## Guantelete del jefe: tres mallas hermanas, una por pose; se ve una sola.

enum Pose { OPEN, FIST, CLAW }

@export var pose := Pose.OPEN:
	set(value):
		pose = value
		if is_inside_tree():
			_show_pose()


func _ready() -> void:
	_show_pose()


func _show_pose() -> void:
	$Open.visible = pose == Pose.OPEN
	$Fist.visible = pose == Pose.FIST
	$Claw.visible = pose == Pose.CLAW
