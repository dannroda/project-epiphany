class_name ItemBehavior
extends Resource
## Sin estado: el recurso lo comparten todos los que usan el ítem.

@export var ammo: ItemData ## null = munición infinita
## En qué punto de la animación (0..1) se llama a use().
@export_range(0.0, 1.0) var use_at := 0.5
## Desde qué punto de la animación (0..1) el player vuelve a moverse.
@export_range(0.0, 1.0) var end_at := 1.0
## Mantener el botón apunta (estado AimingItem) y soltarlo lo usa, como el arco.
@export var hold_to_aim := false
## Mantenerlo más que esto (s) lo levanta para apuntar y tirarlo (AimingThrow, las bombas); 0 = no se mantiene.
@export var hold_time := 0.0

@export_group("Apuntar")
## La animación de tensar mientras se apunta (AimingItem); su largo es lo que tarda en cargar.
@export var aim_animation: StringName
## Cuánto se gira el modelo para que el disparo salga hacia la mira (la animación del arco tensa 62° a la izquierda).
@export var aim_yaw_offset_deg := 0.0


## El evento de la máquina de estados del player con el que arranca: el ítem decide, no la HSM.
func entry_event() -> StringName:
	return &"aim_item" if hold_to_aim else &"use_item"


func get_animation(_item: ItemData) -> StringName:
	return &""


func can_use(_ctx: ItemUseContext, _item: ItemData) -> bool:
	return true


func use(_ctx: ItemUseContext, _item: ItemData) -> void:
	pass
