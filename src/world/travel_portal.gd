@tool
class_name TravelPortal
extends Area3D
## Portal de viaje rápido (7.9): se prende la primera vez que pasa un player y queda guardado (`ow_portal_<id>`).
## Parado encima, interactuar abre el Mapa para elegir destino. Se llega a su `Arrival`.

const GROUP := &"travel_portals"

@export var id: StringName:
	set(value):
		id = value
		update_configuration_warnings()
@export var display_name := ""
@export var lit_material: Material
@export var unlit_material: Material

var flag: StringName:
	get:
		return StringName("ow_portal_%s" % id)
var lit := false

@onready var arrival: SpawnPoint = $Arrival
@onready var interactable: Interactable = $Interactable
@onready var persistent: PersistentFlag = $PersistentFlag


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group(GROUP)
	PhysicsLayers.sensor(self)
	arrival.id = spawn_id()
	persistent.flag = flag
	persistent.changed.connect(func(value: Variant) -> void: _set_lit(value == true))
	_set_lit(persistent.value == true)
	body_entered.connect(func(body: Node3D) -> void:
		if body is PlayerCharacter and not lit:
			persistent.value = true
			Feel.sfx(&"secret", global_position))
	interactable.interacted.connect(func(_by: PlayerCharacter) -> void: MenuStack.open_map())


func _get_configuration_warnings() -> PackedStringArray:
	return PersistentFlag.warnings_for(flag, false, self) if id != &"" else PackedStringArray(["Falta el id."])


func spawn_id() -> StringName:
	return StringName("portal_%s" % id)


## Todos los portales de la escena actual.
static func all(tree: SceneTree) -> Array[TravelPortal]:
	var portals: Array[TravelPortal] = []
	portals.assign(tree.get_nodes_in_group(GROUP))
	return portals


func travel() -> void:
	SceneFlow.travel_to(get_tree().current_scene.scene_file_path, spawn_id(), true)


func _set_lit(value: bool) -> void:
	lit = value
	interactable.enabled = lit
	for mesh: MeshInstance3D in [$Visual/Disc, $Visual/Ring]:
		mesh.material_override = lit_material if lit else unlit_material
	$Visual/Beam.visible = lit
	$Visual/Light.visible = lit
