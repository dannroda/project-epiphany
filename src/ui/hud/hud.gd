extends CanvasLayer
## HUD del juego. Por ahora solo los corazones; después los slots X/Y (3.5), llaves (6.3) y la barra del jefe (9.2).

const HP_PER_HEART := 4

@export var pulse_scale := 1.3
@export var pulse_time := 0.18

@onready var hearts: HBoxContainer = %Hearts

var _health: Health
var _shown_hp := -1


func _ready() -> void:
	_bind_player.call_deferred()


func _bind_player() -> void:
	if not is_inside_tree():
		return
	var player := get_tree().get_first_node_in_group(&"player") as PlayerCharacter
	if player == null:
		return
	_health = player.health
	_health.changed.connect(_on_health_changed)
	_on_health_changed(_health.current, _health.max_health)


func _on_health_changed(current: int, max_value: int) -> void:
	var count := ceili(max_value / float(HP_PER_HEART))
	while hearts.get_child_count() < count:
		hearts.add_child(HeartIcon.new())
	while hearts.get_child_count() > count:
		var extra := hearts.get_child(hearts.get_child_count() - 1)
		hearts.remove_child(extra)
		extra.queue_free()
	for i in count:
		var heart := hearts.get_child(i) as HeartIcon
		var quarters := clampi(current - i * HP_PER_HEART, 0, HP_PER_HEART)
		if heart.quarters != quarters and _shown_hp >= 0:
			_pulse(heart)
		heart.quarters = quarters
	_shown_hp = current


func _pulse(heart: Control) -> void:
	var tween := heart.create_tween()
	heart.scale = Vector2.ONE * pulse_scale
	tween.tween_property(heart, "scale", Vector2.ONE, pulse_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
