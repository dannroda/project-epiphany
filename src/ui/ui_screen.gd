class_name UiScreen
extends Control
## Un estado de la máquina de UI (`MenuStack`): solo la pantalla de arriba de la pila recibe input y foco.
## Al quedar tapada se desactiva, y se oculta si la nueva la cubre (`hides_below`).

## Atrás no la cierra: hay que elegir una opción (game over, confirmaciones).
@export var modal := false
## La pantalla de abajo se oculta mientras esta está abierta (menús a pantalla completa).
@export var hides_below := true
## Pausa y Mapa también la cierran (el menú de pausa).
@export var closes_with_pause := false


## Al entrar a la pila.
func screen_enter() -> void:
	pass


## Al salir de la pila (justo antes de liberarse).
func screen_exit() -> void:
	pass


## Otra pantalla quedó encima.
func screen_covered() -> void:
	pass


## La de encima se cerró: esta vuelve a ser la activa.
func screen_uncovered() -> void:
	pass


## Atrás: true si la pantalla lo resolvió sola (p. ej. salir de un modo); si no, la pila la cierra.
func cancel() -> bool:
	return false


func focus_default() -> void:
	pass
