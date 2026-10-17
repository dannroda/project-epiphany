extends MeshInstance3D
## Una onda del rugido: el clip "spread" anima cuánto creció (0 → `size`) y cuánto avanzó (0 → `reach`).

var size := 1.9
var reach := 1.6
var origin := Vector3.ZERO
var forward := Vector3.FORWARD

var grow := 0.0:
	set(value):
		grow = value
		scale = Vector3.ONE * size * lerpf(0.15, 1.0, value)
var travel := 0.0:
	set(value):
		travel = value
		if is_inside_tree():
			global_position = origin + forward * reach * value


func spread() -> void:
	($Spread as AnimationPlayer).play(&"spread")
