class_name Blessing
extends Node3D
## Lo que se ve mientras dura la bendición del agua bendita (Health.ward): chispas de neón que suben y un resplandor
## celeste; titila los últimos segundos y se apaga sola.

const WARN_TIME := 3.0

var health: Health

@onready var _sparks: CPUParticles3D = $Sparks
@onready var _glow: Node3D = $Glow


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
	var left := health.ward_left()
	visible = left > WARN_TIME or fmod(left, 0.4) > 0.15
	_sparks.emitting = visible
	_glow.visible = visible
