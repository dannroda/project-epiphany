extends "res://tests/test_case.gd"
## ArenaFighter (16.12, 16.13): las esperas de un sub-jefe son del nodo, y todos los peleadores comparten la base.

const FIGHTERS := [
	"res://src/entities/centinela/centinela.tscn",
	"res://src/entities/watcher_eye/watcher_eye.tscn",
	"res://src/entities/kuntur/kuntur.tscn",
	"res://src/entities/amaru/amaru.tscn",
	"res://src/entities/mummy_guard/mummy_guard.tscn",
	"res://src/entities/hand_guard/hand_guard.tscn",
]


func test_a_wait_dies_with_its_fighter() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var fighter := (load(FIGHTERS[0]) as PackedScene).instantiate() as ArenaFighter
	tree.root.add_child(fighter)
	var resumed := [false]
	var waiter := func() -> void:
		await fighter._wait(0.05)
		resumed[0] = true
	waiter.call()
	fighter.free()
	await tree.create_timer(0.2).timeout
	assert_true(not resumed[0], "una espera pendiente no sigue después de liberar al peleador")


func test_every_fighter_is_an_arena_fighter() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	for path: String in FIGHTERS:
		var fighter := (load(path) as PackedScene).instantiate()
		tree.root.add_child(fighter)
		assert_true(fighter is ArenaFighter, path + " es un ArenaFighter")
		if fighter is ArenaFighter:
			assert_true((fighter as ArenaFighter).body != null and (fighter as ArenaFighter).health != null, path + " tiene cuerpo y vida")
			var moves := (fighter as ArenaFighter).moves
			if moves:
				for clip in moves.get_animation_list():
					assert_true(moves.get_animation(clip).get_track_count() > 0, path + " tiene el clip " + clip + " con pistas")
				assert_true(moves.has_animation(&"die"), path + " tiene clip de muerte")
		fighter.free()


func test_tweens_wait_stops_with_the_pause_not_with_the_node() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var node := Node.new()
	node.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.root.add_child(node)
	var resumed := [false]
	var waiter := func() -> void:
		await Tweens.wait(node, 0.05)
		resumed[0] = true
	Pause.hold(&"test")
	waiter.call()
	await tree.create_timer(0.2, true).timeout
	assert_true(not resumed[0], "en pausa no avanza aunque el nodo procese siempre")
	Pause.release(&"test")
	await tree.create_timer(0.2).timeout
	assert_true(resumed[0], "sin pausa termina")
	node.process_mode = Node.PROCESS_MODE_DISABLED
	resumed[0] = false
	waiter.call()
	await tree.create_timer(0.2).timeout
	assert_true(resumed[0], "un nodo dormido no frena la espera, como un timer del árbol")
	node.free()
