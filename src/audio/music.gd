# Autoload
extends Node
## Música por capas: todas suenan en sincronía y cada una sube o baja según dónde está el player.
## Overworld: calma. Templo: la base oscura y, sala a sala según su `Room.doom`, pulso, murmullo y latido.
## Con un menú o una caja de texto abierta, la música baja (ducking). El murmullo va por el bus Ambience.

const LAYERS: Array[StringName] = [&"calm", &"dark", &"pulse", &"murmur", &"heartbeat"]
const TITLE := "res://src/ui/title/title_screen.tscn"
const DUCK_DB := -8.0
## Cuánto cambia el volumen (lineal) por segundo.
const FADE_SPEED := 0.6

var players: Dictionary[StringName, AudioStreamPlayer] = {}
var levels: Dictionary[StringName, float] = {}
var _duck := 0.0
var _menu_open := false
var _boss_owners: Dictionary[Node, bool] = {}

## Pelea con el jefe (placeholder hasta tener su tema): todas las capas del templo al máximo. Suena mientras alguna
## arena la tenga (hold_boss); una que se va del árbol la suelta sola.
var boss_fight: bool:
	get:
		return not _boss_owners.is_empty()


## Cada capa es un hijo con su nombre (music.tscn).
func _ready() -> void:
	for layer in LAYERS:
		var player := get_node(NodePath(layer)) as AudioStreamPlayer
		var stream := player.stream as AudioStreamWAV
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
		players[layer] = player
		levels[layer] = 0.0
	for player in players.values():
		player.play()
	MenuStack.changed.connect(func() -> void: _menu_open = MenuStack.is_open())


## Volumen (0..1) que debería tener cada capa ahora. Sin escena (cargando una partida), cada una queda como está.
func targets() -> Dictionary[StringName, float]:
	var wanted: Dictionary[StringName, float] = {}
	for layer in LAYERS:
		wanted[layer] = 0.0
	var scene := get_tree().current_scene
	if scene == null:
		return levels.duplicate()
	if scene.scene_file_path == TITLE:
		wanted[&"dark"] = 0.6
		wanted[&"murmur"] = 0.3
	elif GameState.current_dungeon != &"":
		var doom := current_doom()
		wanted[&"dark"] = 1.0
		wanted[&"pulse"] = clampf((doom - 0.15) / 0.3, 0.0, 1.0)
		wanted[&"murmur"] = clampf((doom - 0.45) / 0.3, 0.0, 1.0)
		wanted[&"heartbeat"] = clampf((doom - 0.7) / 0.2, 0.0, 1.0)
		if boss_fight:
			for layer in [&"pulse", &"murmur", &"heartbeat"]:
				wanted[layer] = 1.0
	elif not Players.all.is_empty():
		wanted[&"calm"] = 1.0
	return wanted


func hold_boss(owner: Node) -> void:
	if _boss_owners.has(owner):
		return
	_boss_owners[owner] = true
	var release := release_boss.bind(owner)
	if not owner.tree_exiting.is_connected(release):
		owner.tree_exiting.connect(release)


func release_boss(owner: Node) -> void:
	_boss_owners.erase(owner)


func current_doom() -> float:
	var camera := TopDownCamera.current(get_tree())
	return camera.room.doom if camera and camera.room else 0.0


func _process(delta: float) -> void:
	var duck_target := DUCK_DB if _menu_open else 0.0
	_duck = move_toward(_duck, duck_target, 30.0 * delta)
	var wanted := targets()
	for layer in LAYERS:
		levels[layer] = move_toward(levels[layer], wanted[layer], FADE_SPEED * delta)
		var volume := linear_to_db(maxf(levels[layer], 0.0001)) + _duck
		# Cada cambio de volumen hace que el AudioServer reemplace los datos de bus del sonido; sin cambios, no se toca.
		if not is_equal_approx(players[layer].volume_db, volume):
			players[layer].volume_db = volume
