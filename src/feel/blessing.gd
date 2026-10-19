class_name Blessing
extends Node3D
## Lo que se ve mientras dura la bendición del agua bendita (Health.ward): chispas de neón que suben y un resplandor
## celeste; titila los últimos segundos y se apaga sola.

const WARN_TIME := 3.0

var health: Health

@onready var _sparks: CPUParticles3D = $Sparks
@onready var _warn: AnimationPlayer = $Warn


static func attach(user: Node3D, user_health: Health) -> Blessing:
	var blessing := user.get_node_or_null(^"Blessing") as Blessing
	if blessing == null:
		blessing = (load("res://src/feel/blessing.tscn") as PackedScene).instantiate()
		blessing.health = user_health
		user.add_child(blessing)
	Feel.burst(&"sparkle", user.global_position + Vector3.UP, Vector3.UP)
	return blessing


func _process(_delta: float) -> void:
	if health == null or not health.is_warded():
		queue_free()
		return
	var warning := health.ward_left() <= WARN_TIME
	if warning and not _warn.is_playing():
		_warn.play(&"blink")
	elif not warning and _warn.is_playing():
		_warn.stop()
		visible = true
		_sparks.emitting = true
