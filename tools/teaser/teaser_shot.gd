class_name TeaserShot
extends Node3D
## Una toma del teaser: la acción (escenario, Inicio, pasos) y los ángulos (TeaserAngle hijos) desde los que se graba.
## Inicio (opcional) pone al player ahí, mirando hacia su -Z. Los TeaserStep hijos son lo que hace el player; si hay una
## toma jugada por Daniel en takes/<toma>.json, record.sh --tomas la usa en vez de los pasos.

@export var scenario := "templo_video"
@export var length := 4.0
@export var settle := 1.5
@export var rng_seed := 1
@export var show_player := true
@export var clear_enemies := false
## Con el jefe final: apenas empieza la pelea, lo pasa a esta fase sin la presentación (la cámara no se mueve).
@export var boss_phase := 1
## Nodos del nivel (nombres con comodines, como PlumaSpikes_*) que quedan quietos durante la toma.
@export var freeze: PackedStringArray = []


func steps() -> Array[TeaserStep]:
	var list: Array[TeaserStep] = []
	for node in find_children("*", "TeaserStep", true, false):
		list.append(node)
	list.sort_custom(func(a: TeaserStep, b: TeaserStep) -> bool: return a.at < b.at)
	return list


func angles() -> Array[TeaserAngle]:
	var list: Array[TeaserAngle] = []
	for node in get_children():
		if node is TeaserAngle:
			list.append(node)
	return list
