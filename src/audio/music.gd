# Autoload
extends Node
## Música por capas: todas suenan en sincronía y cada una sube o baja según dónde está el player.
## Overworld: calma. Templo: la base oscura y, sala a sala según su `Room.doom`, pulso, murmullo y latido.
## Con un menú o una caja de texto abierta, la música baja (ducking). El murmullo va por el bus Ambience.
## El jefe final tiene su tema (tools/audio/render_boss_music.py): boss_drums desde que arranca, boss_theme desde la
## fase 2 y boss_fury en la 3; los loops de 16 s van en sincronía con los de 8.

const LAYERS: Array[StringName] = [&"calm", &"dark", &"pulse", &"murmur", &"heartbeat", &"boss_drums", &"boss_theme", &"boss_fury"]
const TITLE := "res://src/ui/title/title_screen.tscn"
const DUCK_DB := -8.0
## Cuánto cambia el volumen (lineal) por segundo.
const FADE_SPEED := 0.6

var players: Dictionary[StringName, AudioStreamPlayer] = {}
var levels: Dictionary[StringName, float] = {}
var _duck := 0.0
var _menu_open := false
## Cada arena que tiene la música de pelea, con la fase de su jefe si trae tema propio.
var _boss_owners: Dictionary[Node, Callable] = {}

## Pelea con un jefe: con tema propio (hold_boss con `phase`), sus capas; si no, todas las del templo al máximo. Suena
## mientras alguna arena la tenga; una que se va del árbol la suelta sola.
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
		var phase := boss_theme_phase()
		if phase >= 0:
			wanted[&"dark"] = 0.3
			wanted[&"pulse"] = 0.0
			wanted[&"murmur"] = 0.0
			wanted[&"heartbeat"] = 0.0
			wanted[&"boss_drums"] = 1.0
			wanted[&"boss_theme"] = 1.0 if phase >= 2 else 0.0
			wanted[&"boss_fury"] = 1.0 if phase >= 3 else 0.0
		elif boss_fight:
			for layer in [&"pulse", &"murmur", &"heartbeat"]:
				wanted[layer] = 1.0
	elif not Players.all.is_empty():
		wanted[&"calm"] = 1.0
	return wanted


## `phase`: devuelve la fase del jefe (0 en la presentación) y pide su tema propio.
func hold_boss(owner: Node, phase := Callable()) -> void:
	if _boss_owners.has(owner):
		return
	_boss_owners[owner] = phase
	var release := release_boss.bind(owner)
	if not owner.tree_exiting.is_connected(release):
		owner.tree_exiting.connect(release)


func release_boss(owner: Node) -> void:
	_boss_owners.erase(owner)


## La fase más alta entre las arenas con tema propio; -1 si ninguna lo tiene.
func boss_theme_phase() -> int:
	var phase := -1
	for owner in _boss_owners:
		if _boss_owners[owner].is_valid():
			phase = maxi(phase, _boss_owners[owner].call())
	return phase


func current_doom() -> float:
	var camera := TopDownCamera.find(get_tree())
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
