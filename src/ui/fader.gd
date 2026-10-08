# Autoload
extends CanvasLayer

var _rect := ColorRect.new()


func _ready() -> void:
	layer = 100
	process_mode = PROCESS_MODE_ALWAYS
	_rect.color = Color(0, 0, 0, 0)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)


func fade_out(seconds: float = 0.4) -> void:
	await _fade(1.0, seconds)


func fade_in(seconds: float = 0.4) -> void:
	await _fade(0.0, seconds)


func _fade(alpha: float, seconds: float) -> void:
	var tween := create_tween()
	tween.tween_property(_rect, "color:a", alpha, seconds)
	await tween.finished
