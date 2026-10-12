class_name Afterimage
extends MeshInstance3D
## Una pose congelada que se desvanece (el fantasma de la esquiva).


func fade_out(lifetime: float) -> void:
	set_instance_shader_parameter(&"fade", 1.0)
	var tween := create_tween()
	tween.tween_method(func(value: float) -> void: set_instance_shader_parameter(&"fade", value), 1.0, 0.0, lifetime).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)
