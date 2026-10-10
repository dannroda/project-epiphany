# Autoload
extends Node
## Música por capas: todas suenan en sincronía y cada una sube o baja según dónde está el player.
## Overworld: calma. Templo: la base oscura y, sala a sala según su `Room.doom`, pulso, murmullo y latido.
## Con un menú o una caja de texto abierta, la música baja (ducking). El murmullo va por el bus Ambience.

const BUS := &"Music"
const LAYERS: Array[StringName] = [&"calm", &"dark", &"pulse", &"murmur", &"heartbeat"]
const FOLDER := "res://assets/audio/music/"
const TITLE := "res://src/ui/title/title_screen.tscn"
const DUCK_DB := -8.0
## Cuánto cambia el volumen (lineal) por segundo.
const FADE_SPEED := 0.6

var players: Dictionary[StringName, AudioStreamPlayer] = {}
var levels: Dictionary[StringName, float] = {}
var _duck := 0.0
## Pelea con el jefe (placeholder hasta tener su tema): todas las capas del templo al máximo.
var boss_fight := false


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	for layer in LAYERS:
		var stream := load(FOLDER + layer + ".wav") as AudioStreamWAV
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
		var player := AudioStreamPlayer.new()
		player.name = String(layer)
		player.stream = stream
		player.bus = &"Ambience" if layer == &"murmur" else BUS
		player.volume_db = -80.0
		add_child(player)
		players[layer] = player
		levels[layer] = 0.0
	for player in players.values():
		player.play()


## Volumen (0..1) que debería tener cada capa ahora.
func targets() -> Dictionary[StringName, float]:
	var wanted: Dictionary[StringName, float] = {}
	for layer in LAYERS:
		wanted[layer] = 0.0
	var scene := get_tree().current_scene
	if scene == null:
		return wanted
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
	elif get_tree().get_first_node_in_group(&"player"):
		wanted[&"calm"] = 1.0
	return wanted


func current_doom() -> float:
	var camera := get_tree().get_first_node_in_group(&"room_camera") as TopDownCamera
	return camera.room.doom if camera and camera.room else 0.0


func _process(delta: float) -> void:
	var menus := get_node_or_null(^"/root/MenuStack")
	var duck_target := DUCK_DB if menus and menus.is_open() else 0.0
	_duck = move_toward(_duck, duck_target, 30.0 * delta)
	var wanted := targets()
	for layer in LAYERS:
		levels[layer] = move_toward(levels[layer], wanted[layer], FADE_SPEED * delta)
		players[layer].volume_db = linear_to_db(maxf(levels[layer], 0.0001)) + _duck
