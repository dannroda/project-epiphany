extends PlayerState
## Co-op (13.4): el caído flota detrás del que sigue vivo. Revive si un vivo se le queda cerca un momento o al pasar
## a otra sala (TopDownCamera), con `revive_health`.

@export var revive_health := 4
@export var revive_radius := 0.8
@export var revive_time := 1.0
## Distancia a la que sigue al vivo más cercano.
@export var follow_distance := 2.0
@export var follow_speed := 3.0
@export var float_height := 1.0
## Cuánto crece el espíritu mientras lo reviven.
@export var revive_grow := 0.6

var _touch := 0.0
var _layers := Vector2i.ZERO


func _enter() -> void:
	_touch = 0.0
	_layers = Vector2i(player.collision_layer, player.collision_mask)
	player.collision_layer = 0
	player.collision_mask = 0
	player.velocity = Vector3.ZERO
	player.model.visible = false
	player.spirit.visible = true
	player.spirit.scale = Vector3.ONE
	player.spirit.position.y = float_height
	(player.get_node(^"%SpiritBob") as AnimationPlayer).play(&"bob")


func _exit() -> void:
	player.collision_layer = _layers.x
	player.collision_mask = _layers.y
	player.model.visible = true
	player.spirit.visible = false
	var bob := player.get_node_or_null(^"%SpiritBob") as AnimationPlayer
	if bob:
		bob.stop()
	player.anim_tree.active = true
	player.health.make_invulnerable(player.health.invulnerability_time * 2.0)


func _update(delta: float) -> void:
	player.velocity = Vector3.ZERO
	var living := Players.nearest(player.global_position)
	if living == null:
		return
	var to := living.global_position - player.global_position
	to.y = 0.0
	if to.length() > follow_distance:
		player.global_position += to.normalized() * minf(to.length() - follow_distance, follow_speed * delta)
	player.global_position.y = lerpf(player.global_position.y, living.global_position.y, minf(1.0, 4.0 * delta))
	_touch = _touch + delta if to.length() <= revive_radius else maxf(_touch - delta, 0.0)
	player.spirit.scale = Vector3.ONE * (1.0 + revive_grow * _touch / revive_time)
	if _touch >= revive_time:
		player.revive()
