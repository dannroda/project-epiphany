extends PlayerState

@export var animation: StringName = &"General/Death_A"
## Cuánto queda en el piso antes del game over (o de volverse espíritu si otro sigue vivo).
@export var delay := 1.8


func _enter() -> void:
	player.attack_runner.stop()
	player.velocity = Vector3.ZERO
	player.anim_tree.active = false
	player.anim_player.play(animation, 0.1)
	await Tweens.wait(player, delay)
	if not is_active():
		return
	if Players.any_alive():
		dispatch("spirit")
	elif not _game_over_open():
		GameOver.open()


func _game_over_open() -> bool:
	return MenuStack.top() is GameOver


func _update(delta: float) -> void:
	if not player.is_on_floor():
		player.velocity += player.fall_gravity() * delta
	player.velocity.x = 0.0
	player.velocity.z = 0.0
	player.move_and_slide()
