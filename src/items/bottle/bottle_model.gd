@tool
class_name BottleModel
extends Node3D
## La botella de vidrio con su contenido: el color y el brillo del líquido salen del ítem (ItemData.liquid), así
## cualquier botella lleva cualquier contenido. Sin contenido (o con alfa 0) se ve vacía.

@export var content: ItemData:
	set(value):
		content = value
		if is_node_ready():
			_apply()

var _liquid_material := StandardMaterial3D.new()

@onready var liquid: MeshInstance3D = $Liquid


func _ready() -> void:
	liquid.material_override = _liquid_material
	_apply()


func _apply() -> void:
	var color := content.liquid if content else Color(0, 0, 0, 0)
	liquid.visible = color.a > 0.0
	_liquid_material.albedo_color = Color(color, 1.0)
	_liquid_material.roughness = 0.3
	var glow := content.liquid_glow if content else 0.0
	_liquid_material.emission_enabled = glow > 0.0
	_liquid_material.emission = Color(color, 1.0)
	_liquid_material.emission_energy_multiplier = glow
