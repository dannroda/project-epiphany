extends PlayerState

@export var animation: StringName = &"General/Death_A"
## Cuánto queda en el piso antes del game over.
@export var delay := 1.8


func _enter() -> void:
	player.attack_runner.stop()
	player.velocity = Vector3.ZERO
	player.anim_tree.active = false
	player.anim_player.play(animation, 0.1)
	await player.get_tree().create_timer(delay).timeout
	GameOver.open()


func _update(delta: float) -> void:
	if not player.is_on_floor():
		player.velocity += player.get_gravity() * delta
	player.velocity.x = 0.0
	player.velocity.z = 0.0
	player.move_and_slide()
