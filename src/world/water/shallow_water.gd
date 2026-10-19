@tool
class_name ShallowWater
extends Area3D
## Agua baja que se camina (el Bañado): el terreno orgánico se hunde bajo su rectángulo (export_terreno_overworld marca
## sus celdas) y la superficie solo se ve ahí. Frena a los players que la cruzan, que salpican al andar.

const SURFACE_Y := -0.08
const STEP_TIME := 0.3
## La superficie se pasa este margen (m) del rectángulo: la orilla la dibuja el pozo del terreno, que ondula. Del lado
## que toca otra ShallowWater no se pasa, así las dos no se pisan (el agua es transparente y se vería el doble).
const MARGIN := 1.4
const GROUP := &"shallow_water"

## Medidas en XZ (m).
@export var size := Vector2(8.0, 6.0):
	set(value):
		size = value
		if is_node_ready():
			_build()
## Velocidad de los players adentro (1 = la de siempre).
@export var wade_speed := 0.6

var _waders: Dictionary[PlayerCharacter, float] = {}

@onready var shape: CollisionShape3D = $CollisionShape3D
@onready var surface: MeshInstance3D = $Surface


func _ready() -> void:
	_build()
	if Engine.is_editor_hint():
		return
	add_to_group(GROUP)
	collision_layer = 0
	collision_mask = 1 | 2
	monitorable = false
	body_entered.connect(func(body: Node3D) -> void:
		var player := body as PlayerCharacter
		if player:
			_waders[player] = 0.0
			player.ground_speed = wade_speed)
	body_exited.connect(func(body: Node3D) -> void:
		var player := body as PlayerCharacter
		if player:
			_waders.erase(player)
			player.ground_speed = _speed_elsewhere(player))


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	for player in _waders.keys():
		if not is_instance_valid(player):
			_waders.erase(player)
			continue
		_waders[player] -= delta
		if _waders[player] <= 0.0 and Vector2(player.velocity.x, player.velocity.z).length() > 1.0:
			_waders[player] = STEP_TIME
			var at := Vector3(player.global_position.x, global_position.y + SURFACE_Y, player.global_position.z)
			Feel.burst(&"wade", at, Vector3.UP)
			Feel.sfx(&"wade", at)


func _build() -> void:
	(shape.shape as BoxShape3D).size = Vector3(size.x, 1.2, size.y)
	var lo := Vector2.ONE * MARGIN
	var hi := Vector2.ONE * MARGIN
	if is_inside_tree():
		var mine := _rect()
		for other in get_parent().get_children():
			if other == self or not other is ShallowWater:
				continue
			var theirs: Rect2 = other._rect()
			if not mine.grow(MARGIN * 2.0).intersects(theirs):
				continue
			for axis in 2:
				var across := 1 - axis
				if mine.position[across] >= theirs.end[across] or theirs.position[across] >= mine.end[across]:
					continue
				if absf(mine.position[axis] - theirs.end[axis]) < MARGIN * 2.0:
					lo[axis] = 0.0
				if absf(theirs.position[axis] - mine.end[axis]) < MARGIN * 2.0:
					hi[axis] = 0.0
	(surface.mesh as PlaneMesh).size = size + lo + hi
	surface.position = Vector3((hi.x - lo.x) / 2.0, SURFACE_Y, (hi.y - lo.y) / 2.0)


func _rect() -> Rect2:
	return Rect2(Vector2(position.x, position.z) - size / 2.0, size)


## Las áreas del Bañado se tocan: al salir de una puede que ya esté en la de al lado.
func _speed_elsewhere(player: PlayerCharacter) -> float:
	for water in get_tree().get_nodes_in_group(GROUP):
		if water != self and (water as ShallowWater)._waders.has(player):
			return (water as ShallowWater).wade_speed
	return 1.0
