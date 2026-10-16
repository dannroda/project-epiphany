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
