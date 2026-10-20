class_name Tweens
## `await tween.finished` se queda esperando para siempre si alguien hace kill(): kill no emite finished.


## Vuelve cuando el tween termina (true) o lo matan o se libera su nodo (false).
static func ended(tween: Tween) -> bool:
	var done := [false]
	tween.finished.connect(func() -> void: done[0] = true, CONNECT_ONE_SHOT)
	var tree := Engine.get_main_loop() as SceneTree
	while not done[0] and tween.is_valid():
		await tree.process_frame
	return done[0]


## Como un timer del árbol (para con la pausa, no con el process_mode del nodo), pero si `node` se libera
## quien espera no vuelve.
static func wait(node: Node, seconds: float) -> Signal:
	return node.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP).tween_interval(seconds).finished


## Arranca `clip` de cero aunque ya estuviera sonando; lo que el clip no anima queda como estaba.
static func replay(player: AnimationPlayer, clip: StringName, speed := 1.0) -> void:
	player.speed_scale = speed
	player.stop(true)
	player.play(clip)


## Como `ended`, para el clip que suena en `player`: false si lo cortan (stop, otro clip o volver a arrancarlo) o se
## libera el player.
static func played(player: AnimationPlayer, clip: StringName) -> bool:
	var done := [false]
	var on_finished := func(name: StringName) -> void: done[0] = done[0] or name == clip
	player.animation_finished.connect(on_finished)
	var tree := Engine.get_main_loop() as SceneTree
	var at := player.current_animation_position
	while not done[0] and is_instance_valid(player) and player.current_animation == clip and player.current_animation_position >= at:
		at = player.current_animation_position
		await tree.process_frame
	if is_instance_valid(player):
		player.animation_finished.disconnect(on_finished)
	return done[0]
