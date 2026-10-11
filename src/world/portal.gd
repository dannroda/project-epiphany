class_name Portal
extends Area3D
## Puerta entre escenas (overworld ↔ mazmorra): al entrar el player, fundido y viaje al `SpawnPoint` de la otra escena.
## El punto de llegada va afuera del portal de la otra escena, así no vuelve a dispararse al aparecer.

signal player_entered(player: PlayerCharacter)

@export_file("*.tscn") var target_scene: String
@export var target_spawn: StringName
## Si tiene flag, el portal aparece recién cuando el flag es verdadero (p. ej. al vencer al jefe).
@export var required_flag: StringName
## Si es false no viaja solo: otro nodo decide con `player_entered` (el portal del jefe abre el fin de la demo).
@export var travels := true

## Cerrado aunque su flag esté en true (la revancha del jefe).
var held := false:
	set(value):
		held = value
		_apply()

var _flag_open := true


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 | 2
	monitorable = false
	body_entered.connect(func(body: Node3D) -> void:
		if body is PlayerCharacter and not SaveManager.traveling:
			player_entered.emit(body)
			if travels:
				travel())
	if required_flag != &"":
		_set_open(false)
		var persistent := $PersistentFlag as PersistentFlag
		persistent.flag = required_flag
		persistent.changed.connect(func(value: Variant) -> void: _set_open(value == true))


func travel() -> void:
	SaveManager.travel_to(target_scene, target_spawn)


func _set_open(open: bool) -> void:
	_flag_open = open
	_apply()


func _apply() -> void:
	var open := _flag_open and not held
	visible = open
	set_deferred(&"monitoring", open)
