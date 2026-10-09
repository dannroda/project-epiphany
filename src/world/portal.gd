class_name Portal
extends Area3D
## Puerta entre escenas (overworld ↔ mazmorra): al entrar el player, fundido y viaje al `SpawnPoint` de la otra escena.
## El punto de llegada va afuera del portal de la otra escena, así no vuelve a dispararse al aparecer.

@export_file("*.tscn") var target_scene: String
@export var target_spawn: StringName
## Si tiene flag, el portal aparece recién cuando el flag es verdadero (p. ej. al vencer al jefe).
@export var required_flag: StringName


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 | 2
	monitorable = false
	body_entered.connect(func(body: Node3D) -> void:
		if body is PlayerCharacter and not SaveManager.traveling:
			SaveManager.travel_to(target_scene, target_spawn))
	if required_flag != &"":
		_set_open(false)
		var persistent := PersistentFlag.new()
		persistent.flag = required_flag
		persistent.changed.connect(func(value: Variant) -> void: _set_open(value == true))
		add_child(persistent)


func _set_open(open: bool) -> void:
	visible = open
	set_deferred(&"monitoring", open)
