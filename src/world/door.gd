@tool
class_name Door
extends StaticBody3D
## Puerta de mazmorra. La hoja se hunde al abrirse (la colisión se apaga al terminar) y sube al cerrarse.
## LOCKED/BOSS se abren con llave al interactuar y quedan abiertas por su flag; SHUTTER la cierra su Room
## mientras tenga enemigos; SWITCH la abre la señal `activated` de un interruptor.

signal opened
signal closed

const GROUP := &"doors"

enum Kind { OPEN, LOCKED, SHUTTER, SWITCH, BOSS }

const LEAVES := {
	Kind.OPEN: "puerta_madera",
	Kind.LOCKED: "puerta_llave",
	Kind.SHUTTER: "puerta_persiana",
	Kind.SWITCH: "puerta_interruptor",
	Kind.BOSS: "puerta_jefe",
}
const LEAF_MESH := "res://assets/epiphany/meshes/templo/%s.res"
const TEXTS: DialogueResource = preload("res://data/dialogue/doors.dialogue")
const BOSS_TINT := Color(1.0, 0.45, 0.4)

@export var kind: Kind = Kind.OPEN:
	set(value):
		kind = value
		update_configuration_warnings()
## Persistencia para LOCKED / BOSS.
@export var flag: StringName:
	set(value):
		flag = value
		update_configuration_warnings()
## SHUTTER: la sala que la cierra mientras tenga enemigos.
@export var room: Room
## SWITCH: los interruptores que la abren y si hacen falta todos o alguno.
@export var switches: Array[NodePath] = []:
	set(value):
		switches = value
		update_configuration_warnings()
@export var condition: Wiring.Condition = Wiring.Condition.ALL
## Si es false, se vuelve a cerrar cuando la condición deja de cumplirse.
@export var stays_open := true
## La primera vez que la abre un interruptor, el juego se pausa y la cámara la muestra.
@export var reveal_on_open := true
@export var open_time := 0.5
## Fondo del paso en el que está: la colisión lo cubre entero; la hoja es una sola, en el medio.
@export var depth := 0.0
## Ruta de las hojas (con %s el nombre de LEAVES) y cuánto bajan al abrirse.
@export var leaf_meshes := LEAF_MESH
@export var sink := 2.5

## 0 cerrada, 1 abierta: la anima el clip "open" de %Swing; la hoja baja `sink` y la colisión se apaga al llegar a 1.
var openness := 0.0:
	set(value):
		openness = value
		if leaf:
			leaf.position.y = _closed_y - sink * openness
		if shape and not Engine.is_editor_hint():
			shape.set_deferred(&"disabled", openness >= 1.0)

@onready var leaf: Node3D = %Leaf
@onready var shape: CollisionShape3D = $CollisionShape3D
@onready var interactable: Interactable = $Interactable
@onready var swing: AnimationPlayer = %Swing

var is_open := false
var _closed_y := 0.0
var _persistent: PersistentFlag
var _wiring: Wiring
## Alto al que la cámara recorta la pared sur de la sala si la puerta está en ella (0: no lo está). La hoja baja a
## ese alto como la pared y, si está cerrada con llave, el candado se muestra en el piso de adelante.
var south_cut := 0.0:
	set(value):
		south_cut = value
		_update_south_mark()


func _ready() -> void:
	_closed_y = leaf.position.y
	if Engine.is_editor_hint():
		return
	add_to_group(GROUP)
	%LeafMesh.mesh = load(leaf_meshes % LEAVES[kind])
	_fill_depth()
	interactable.enabled = false
	match kind:
		Kind.OPEN, Kind.SHUTTER:
			open(false)
		Kind.LOCKED, Kind.BOSS:
			interactable.enabled = true
			interactable.interacted.connect(func(_by: PlayerCharacter) -> void: try_unlock())
			_persistent = $PersistentFlag
			_persistent.flag = flag
			_persistent.changed.connect(func(value: Variant) -> void:
				if value == true:
					open(false)
				else:
					close(false)
				interactable.enabled = value != true)
			if _persistent.value == true:
				open(false)
				interactable.enabled = false
		Kind.SWITCH:
			_wiring = Wiring.create(self, switches, condition).drive(self, open, close)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PersistentFlag.warnings_for(flag, kind not in [Kind.LOCKED, Kind.BOSS], self)
	if kind == Kind.SHUTTER and room == null:
		warnings.append("Una persiana necesita su Room.")
	if kind == Kind.SWITCH and switches.is_empty():
		warnings.append("Una puerta con interruptor necesita al menos un interruptor en `switches`.")
	return warnings


func _fill_depth() -> void:
	if depth <= 0.0:
		return
	var box := shape.shape.duplicate() as BoxShape3D
	box.size.z = depth
	shape.shape = box
	var reach := $Interactable/CollisionShape3D as CollisionShape3D
	var area := reach.shape.duplicate() as BoxShape3D
	area.size.z += depth
	reach.shape = area


## Con llave: gasta una llave chica (LOCKED) o pide la del jefe (BOSS).
func try_unlock() -> bool:
	if is_open:
		return true
	var dungeon := GameState.current_dungeon_state()
	match kind:
		Kind.LOCKED:
			if dungeon.small_keys <= 0:
				_refuse(&"locked")
				return false
			dungeon.small_keys -= 1
		Kind.BOSS:
			if not dungeon.has_boss_key:
				_refuse(&"boss_locked")
				return false
		_:
			return false
	interactable.enabled = false
	open(true)
	_persistent.value = true
	return true


func open(animate: bool = true) -> void:
	if is_open:
		return
	is_open = true
	_move_leaf(animate, true)
	_update_south_mark()
	opened.emit()


func close(animate: bool = true) -> void:
	if not is_open:
		return
	is_open = false
	shape.set_deferred(&"disabled", false)
	_move_leaf(animate, false)
	_update_south_mark()
	closed.emit()


func _move_leaf(animate: bool, opening: bool) -> void:
	if not animate:
		Clips.jump(swing, &"open", opening)
		return
	Feel.sfx(&"door", global_position)
	Feel.burst(&"dust", global_position + Vector3.UP * 0.1, Vector3.UP)
	Clips.run(swing, &"open", opening, open_time)


func _update_south_mark() -> void:
	if not is_node_ready():
		return
	var height := (%LeafMesh as MeshInstance3D).get_aabb().size.y
	var cut := south_cut > 0.0 and south_cut < height
	leaf.scale.y = south_cut / height if cut else 1.0
	var mark := %SouthMark as Sprite3D
	mark.visible = cut and not is_open and kind in [Kind.LOCKED, Kind.BOSS]
	mark.modulate = BOSS_TINT if kind == Kind.BOSS else Color.WHITE
	mark.position.z = -maxf(depth, 0.3) / 2.0 - 1.0


func _refuse(cue: StringName) -> void:
	Feel.sfx(&"deny", global_position)
	TextBox.open(TEXTS, cue)
