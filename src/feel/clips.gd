class_name Clips
## Clips de ida y vuelta (abrir/cerrar): el clip se dibuja en el editor y dura lo que pida cada instancia.


## Corre el clip en `seconds`, hacia adelante o hacia atrás desde donde esté, sin saltar si se cortó a la mitad.
static func run(player: AnimationPlayer, clip: StringName, forward: bool, seconds: float) -> void:
	player.speed_scale = player.get_animation(clip).length / maxf(seconds, 0.001)
	if forward:
		player.play(clip)
	else:
		player.play_backwards(clip)


## Lo deja al principio o al final sin animar, y de ahí sigue la próxima vez que corra.
static func jump(player: AnimationPlayer, clip: StringName, to_end: bool) -> void:
	player.play(clip)
	player.seek(player.get_animation(clip).length if to_end else 0.0, true)
	player.pause()
