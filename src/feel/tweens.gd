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
