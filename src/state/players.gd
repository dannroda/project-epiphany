# Autoload
extends Node
## Los players en juego (co-op, M13). Ningún sistema asume uno solo: la IA y lo que busca a alguien eligen al más
## cercano; lo que todavía es de uno (cámara, guardado, menús, HUD) usa al primero, `lead()`, hasta 13.3 y 13.5.

signal joined(player: PlayerCharacter)
signal left(player: PlayerCharacter)

var all: Array[PlayerCharacter] = []


func register(player: PlayerCharacter) -> void:
	if all.has(player):
		return
	all.append(player)
	joined.emit(player)


func unregister(player: PlayerCharacter) -> void:
	if all.has(player):
		all.erase(player)
		left.emit(player)


func lead() -> PlayerCharacter:
	return all[0] if not all.is_empty() else null


func alive() -> Array[PlayerCharacter]:
	return all.filter(func(player: PlayerCharacter) -> bool: return not player.is_dead)


func any_alive() -> bool:
	return not alive().is_empty()


## El más cercano a `point` (en XZ), vivo salvo que `living` sea false; null si no hay.
func nearest(point: Vector3, living := true) -> PlayerCharacter:
	var best: PlayerCharacter = null
	var best_distance := INF
	for player in (alive() if living else all):
		var distance := Vector2(player.global_position.x - point.x, player.global_position.z - point.z).length()
		if distance < best_distance:
			best = player
			best_distance = distance
	return best
