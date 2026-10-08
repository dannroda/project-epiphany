class_name Portal
extends Area3D
## Puerta entre escenas (overworld ↔ mazmorra): al entrar el player, fundido y viaje al `SpawnPoint` de la otra escena.
## El punto de llegada va afuera del portal de la otra escena, así no vuelve a dispararse al aparecer.

@export_file("*.tscn") var target_scene: String
@export var target_spawn: StringName


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 | 2
	monitorable = false
	body_entered.connect(func(body: Node3D) -> void:
		if body is PlayerCharacter and not SaveManager.traveling:
			SaveManager.travel_to(target_scene, target_spawn))
