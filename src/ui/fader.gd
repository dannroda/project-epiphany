# Autoload (fader.tscn)
extends CanvasLayer

@onready var _rect: ColorRect = $Rect


func fade_out(seconds: float = 0.4) -> void:
	await _fade(1.0, seconds)


func fade_in(seconds: float = 0.4) -> void:
	await _fade(0.0, seconds)


func _fade(alpha: float, seconds: float) -> void:
	var tween := create_tween()
	tween.tween_property(_rect, "color:a", alpha, seconds)
	await tween.finished
