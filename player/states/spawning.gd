extends PlayerState

func _enter() -> void:
	player.anim_player.play(&"General/Spawn_Ground")
	await player.anim_player.animation_finished
	dispatch("idle")
