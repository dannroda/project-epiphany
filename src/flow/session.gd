class_name Session
extends RefCounted
## Lo de esta corrida que no va en el save (lo tiene SceneFlow). Se borra cuando GameState empieza otra partida o
## carga una.

## Mazmorra: dónde quedó el player al entrar a la sala actual; ahí reaparece al morir.
var room_entry: Variant = null
## Revancha contra el jefe ya vencido (10.19): la arena lo trae de vuelta hasta ganarle.
var boss_rematch := false
## Presentaciones de jefe ya vistas (por su flag): la próxima vez se pueden saltear.
var seen_boss_intros := {}


func clear() -> void:
	room_entry = null
	boss_rematch = false
	seen_boss_intros.clear()
