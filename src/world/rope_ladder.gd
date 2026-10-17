class_name RopeLadder
extends Node3D
## Escalera de soga enrollada al borde de un risco: se descuelga desde arriba y queda colgada (flag); después se sube
## y se baja trepando (el player sigue Lip → RungTop → RungBottom → BottomSpot, o al revés). El origen va en el borde de
## arriba y +Z apunta hacia afuera del risco.

## El área de un extremo solo cuenta si el player está así de cerca de donde empieza a trepar (al habilitarla puede
## avisar de un cuerpo que ya no está ahí).
const START_REACH := 2.0

@export var flag: StringName
@export var unroll_time := 0.6

@onready var interactable: Interactable = $Interactable
@onready var coil: Node3D = $Coil
@onready var ladder: Node3D = $Ladder
@onready var top: Area3D = $Top
@onready var bottom: Area3D = $Bottom
@onready var _down: Array[Node3D] = [$Lip, $RungTop, $RungBottom, $BottomSpot]
@onready var _up: Array[Node3D] = [$RungBottom, $RungTop, $Lip, $TopSpot]


func _ready() -> void:
	interactable.interacted.connect(func(_by: PlayerCharacter) -> void: unroll())
	top.body_entered.connect(_climb.bind(_down))
	bottom.body_entered.connect(_climb.bind(_up))
	GameState.loaded.connect(_sync)
	_sync()


func is_down() -> bool:
	return GameState.get_flag(flag) == true


func unroll() -> void:
	if is_down():
		return
	GameState.set_flag(flag, true)
	Feel.sfx(&"secret", global_position)
	_sync()
	Clips.run(%Unroll, &"unroll", true, unroll_time)


func _climb(body: Node3D, path: Array[Node3D]) -> void:
	if not body is PlayerCharacter or not is_down() or SceneFlow.traveling:
		return
	if body.global_position.distance_to(path[0].global_position) > START_REACH:
		return
	var points := PackedVector3Array()
	for spot in path:
		points.append(spot.global_position)
	if (body as PlayerCharacter).climb(points, -global_basis.z.normalized()):
		Feel.sfx(&"stairs", body.global_position)


func _sync() -> void:
	var down := is_down()
	coil.visible = not down
	ladder.visible = down
	interactable.enabled = not down
	interactable.set_deferred(&"monitorable", not down)
	for area: Area3D in [top, bottom]:
		area.set_deferred(&"monitoring", down)
