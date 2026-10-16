class_name TeaserShot
extends Node3D
## Una toma del teaser. GAME graba con la cámara del juego y el HUD; RAIL con la cámara del director, sin HUD, que va
## de From a To (posición y giro) o, si hay un marcador Mira, de From a To mirando a Mira.
## Inicio (opcional) pone al player ahí, mirando hacia su -Z. Los TeaserStep hijos son lo que hace el player.

enum View { GAME, RAIL }

@export var scenario := "templo_video"
@export var view := View.GAME
@export var length := 4.0
@export var settle := 1.5
@export var fov := 45.0
@export var rng_seed := 1
@export var show_player := true
@export var clear_enemies := false
## Nodos del nivel (nombres con comodines, como PlumaSpikes_*) que quedan quietos durante la toma.
@export var freeze: PackedStringArray = []


func steps() -> Array[TeaserStep]:
	var list: Array[TeaserStep] = []
	for node in find_children("*", "TeaserStep", true, false):
		list.append(node)
	list.sort_custom(func(a: TeaserStep, b: TeaserStep) -> bool: return a.at < b.at)
	return list
